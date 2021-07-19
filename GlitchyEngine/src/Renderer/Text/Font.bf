using System;
using FreeType;
using GlitchyEngine.Math;
using System.Collections;

using internal GlitchyEngine.Renderer.Text;

namespace GlitchyEngine.Renderer.Text
{
	public class Font : RefCounted
	{
		internal class GlyphDescriptor
		{
			public Font Font;

			public FT_UInt GlyphIndex;

			public Int32_3 MapCoord;
			public int32 SizeX, SizeY;

			public FT_Glyph_Metrics Metrics;

			public bool IsBitmap;

			public bool IsCalculated = false;
			public bool IsRendered = false;
		}

		private GraphicsContext _context ~ _.ReleaseRef();
		internal FT_Face _face ~ FreeType.Done_Face(_face);

		private Font _fallback ~ _?.ReleaseRef();

		internal uint32 _fontSize;
		private int32 _faceIndex;
		private bool _hasColor;
		
		private Int32_3 _penPos;
		private int32 _lastRowHeight;
		internal Texture2D _atlas ~ _?.ReleaseRef();
		private Int32_3 _atlasSize;

		private Dictionary<char32, GlyphDescriptor> _glyphs = new .() ~ DeleteDictionaryAndValues!(_);
		GlyphDescriptor _missingGlyph;
		
		private SamplerState _sampler ~ _.ReleaseRef();

		/**
		 * Gets or sets the fallback Font for this Font.
		 * The Fallback font will be used to render Glyphs that are not defined in the current font.
		 * @remarks Example: "Arial" doesn't define emojis. Without a fallback font the FontRenderer would draw the null-Glyph (probably just a rectangle).
		 * 		By defining "Segoe UI Emoji" as the Fallback the FontRenderer will use "Arial" to render letters and "Segoe UI Emoji" to render emojis.
		 */
		public Font Fallback
		{
			get => _fallback;
			set
			{
				if(_fallback == value)
					return;

				_fallback = value..AddRef();
			}
		}

		/**
		 * Gets or sets the Sampler that will be used to sample the spritefont.
		 * Setting to null will result in the use of LinearClamp
		 */
		public SamplerState Sampler
		{
			get => _sampler;
			set
			{
				// when value and _sampler are null we don't shortcut because we set _sampler to LinearClamp
				if(_sampler == value && value != null)
					return;

				_sampler?.ReleaseRef();
				
				_sampler = (value ?? SamplerStateManager.LinearClamp)..AddRef();

				_atlas?.SamplerState = _sampler;
			}
		}

		public this(GraphicsContext context, String fontPath, uint32 fontSize, bool hasColor = true, char32 firstChar = '\0', uint32 charCount = 128, int32 faceIndex = 0)
		{
			_context = context..AddRef();
			
			// Set default sampler
			Sampler = null;

			FontRenderer.InitLibrary();

			_glyphs.Add('\0', new GlyphDescriptor(){Font = this});

			_fontSize = fontSize;
			_faceIndex = faceIndex;
			_hasColor = hasColor;

			var res = FreeType.New_Face(FontRenderer.Library, fontPath, faceIndex, &_face);
			Log.EngineLogger.Assert(res.Success, scope $"New_Face failed({(int)res}): {res}");

			res = FreeType.Set_Pixel_Sizes(_face, 0, _fontSize);
			Log.EngineLogger.Assert(res.Success, scope $"Set_Pixel_Sizes failed({(int)res}): {res}");

			LoadGlyphs(firstChar, charCount);
		}

		public void LoadGlyphs(char32 firstChar, uint32 charCount)
		{
			ExtendRange(firstChar, firstChar + charCount);

			UpdateAtlas();
		}

		internal GlyphDescriptor GetGlyph(char32 char, bool allowDynamicLoading = true)
		{
			GlyphDescriptor desc;

			if(_glyphs.TryGetValue(char, out desc))
			{
				// if the char is not defined in the current font try to load it from the fallback
				if(desc == null && _fallback != null)
				{
					desc = _fallback.GetGlyph(char, allowDynamicLoading);
				}
			}
			else if(allowDynamicLoading)
			{
				// TODO: make reloading optional
				char32 start = (char >> 4) << 4;
				LoadGlyphs(start, 64);

				desc = GetGlyph(char, false);
			}

			return desc ?? _missingGlyph;
		}

		void ExtendRange(char32 firstChar, char32 rangeEnd)
		{
			// TODO: refactor

			for(char32 char = firstChar; char < rangeEnd; char++)
			{
				GlyphDescriptor desc = new GlyphDescriptor();
				if(_glyphs.TryAdd(char, desc))
				{
					//desc.Face = _face;
					desc.Font = this;
					desc.GlyphIndex = FreeType.Get_Char_Index(_face, char);

					// if the char is not contained by the font we set the desc to null
					if(desc.GlyphIndex == 0)
					{
						delete desc;
						_glyphs[char] = null;
					}
				}
				else
				{
					delete desc;
				}
			}
		}

		void UpdateAtlas()
		{
			DrawAtlas();
		}

		Int32_3 PrepareAtlas()
		{
			const uint32 maxRes = 16384; // D3D11_REQ_TEXTURE2D_U_OR_V_DIMENSION
			const uint32 maxArray = 2048; // D3D11_REQ_TEXTURE2D_ARRAY_AXIS_DIMENSION
			
			ref Int32_3 pen = ref _penPos;
			ref int32 penLeft = ref _penPos.X;
			ref int32 penTop = ref _penPos.Y;
			ref int32 penArray = ref _penPos.Z;
			ref int32 rowHeight = ref _lastRowHeight;

			int32 atlasWidth = _atlasSize.X;
			int32 atlasHeight = _atlasSize.Y;
			int32 atlasArray = _atlasSize.Z;

			for(let (char, desc) in _glyphs)
			{
				if(desc == null || desc.IsCalculated)
				{
					continue;
				}

				let loadResult = FreeType.Load_Glyph(_face, desc.GlyphIndex, .Color | .TargetNormal);
				if(loadResult.Error)
				{
					Log.EngineLogger.Error($"Failed to load glyph for '{char}'(Char Code:{(uint32)char} | Error {(int)loadResult}): {loadResult}");
				}

				desc.Metrics = _face.glyph.metrics;

				int32 glyphWidth = (desc.Metrics.width / 64) + 1;
				int32 glyphHeight = (desc.Metrics.height / 64) + 1;

				// when size is 0 (1 because we added 1) the glyph has no image
				if(glyphWidth != 1 || glyphHeight != 1)
				{
					int32 glyphRight = penLeft + glyphWidth;

					if(glyphRight > maxRes)
					{
						penLeft = 0;
						penTop += rowHeight;
						rowHeight = 0;
					}

					int32 glyphBottom = penTop + glyphHeight;

					if(glyphBottom > maxRes)
					{
						penLeft = 0;
						penTop = 0;
						rowHeight = 0;

						penArray++;
					}

					if(penArray >= maxArray)
					{
						Log.EngineLogger.Error("Spritefont exceeds maximum texture size.");
					}
				}

				desc.MapCoord = pen;
				desc.SizeX = glyphWidth - 1;
				desc.SizeY = glyphHeight - 1;

				if(desc.GlyphIndex == 0 && _missingGlyph == null)
				{
					_missingGlyph = desc;
				}
				
				penLeft += glyphWidth;

				if (penLeft > atlasWidth)
				    atlasWidth = penLeft;

				if (glyphHeight > rowHeight)
				    rowHeight = glyphHeight;

				if (penTop + glyphHeight > atlasHeight)
				    atlasHeight = penTop + glyphHeight;

				if (penArray == atlasArray)
				    atlasArray++;

				desc.IsCalculated = true;
			}

			return .(atlasWidth, atlasHeight, atlasArray);
		}

		void DrawAtlas()
		{
			Int32_3 oldAtlasSize = _atlasSize;
			_atlasSize = PrepareAtlas();

			if(_atlasSize != oldAtlasSize)
			{
				var oldAtlas = _atlas;

				Texture2DDesc desc;
				desc.Format = .B8G8R8A8_UNorm;
				desc.MipLevels = 1;
				desc.Width = (.)_atlasSize.X;
				desc.Height = (.)_atlasSize.Y;
				desc.ArraySize = (.)_atlasSize.Z;
				desc.CpuAccess = .None;
				desc.Usage = .Default;

				_atlas = new Texture2D(_context, desc);
				_atlas.SamplerState = _sampler;

				if(oldAtlas != null)
				{
					oldAtlas.CopyTo(_atlas);
					oldAtlas.ReleaseRef();
				}
			}

			for(let (char, desc) in _glyphs)
			{
				if(desc == null)
					continue;

				var glyphIndex = desc.GlyphIndex;

				if(desc.IsRendered || glyphIndex == 0 || desc.SizeX == 0 || desc.SizeY == 0)
				{
					continue;
				}

				var loadResult = FreeType.Load_Glyph(_face, glyphIndex, .Color | .Render | .TargetNormal);
				if(loadResult.Error)
				{
					Log.EngineLogger.Error($"Failed to render glyph for '{char}'(Char Code:{(uint32)char} | Error {(int)loadResult}): {loadResult}");
				}
				
				FT_GlyphSlot glyphSlot = _face.glyph;
				FT_Bitmap bitmap = glyphSlot.bitmap;

				//ResourceBox glyphBox = .((.)desc.MapCoord.X, (.)desc.MapCoord.X, 0,
				//	(.)desc.MapCoord.X + (.)desc.SizeX, (.)desc.MapCoord.Y + (.)desc.SizeY, 1);

				if(_face.glyph.format == .Bitmap)
				{
					if(bitmap.pixel_mode == .Gray)
					{
						Color[] pixels = new Color[bitmap.width * bitmap.rows];
						defer delete pixels;

						for(int i < pixels.Count)
						{
							uint8 gray = bitmap.buffer[i];

							pixels[i] = .(gray, gray, gray, gray);
						}

						_atlas.SetData(pixels.Ptr, (.)desc.MapCoord.X, (.)desc.MapCoord.Y,
							(.)desc.SizeX, (.)desc.SizeY, (.)desc.MapCoord.Z);
					}
					else if(bitmap.pixel_mode == .Bgra)
					{
						_atlas.SetData<Color>((.)bitmap.buffer, (.)desc.MapCoord.X, (.)desc.MapCoord.Y,
							(.)desc.SizeX, (.)desc.SizeY, (.)desc.MapCoord.Z);

						desc.IsBitmap = true;
					}
				}
				else
				{
					Runtime.NotImplemented();
				}

				desc.IsRendered = true;
			}
		}
	}
}
