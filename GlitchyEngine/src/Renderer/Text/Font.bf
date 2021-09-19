using System;
using FreeType;
using GlitchyEngine.Math;
using System.Collections;
using msdfgen;

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
		
		/// How much we have to scale the geometry to fit it into our desired pixels
		private double _geometryScaler;

		private double _range = 4.0;

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

		[Inline]
		double F26Dot6ToDouble(int32 value)
		{
			return (double(value) / 64.0);
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

			double unitsPerEm = F26Dot6ToDouble(_face.units_per_EM);
			_geometryScaler = _fontSize / unitsPerEm;

			_range = 4.0 / _geometryScaler;

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

		/// Debug only
		public void RedrawAtlas()
		{
			for(let (char, desc) in _glyphs)
			{
				desc?.IsCalculated = false;
				desc?.IsRendered = false;
			}

			_penPos = .Zero;
			_lastRowHeight = 0;

			UpdateAtlas();
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

				int32 border = 2;

				// TODO: adjust size to glyph
				int32 glyphWidth = (.)_fontSize + border;
				//int32 glyphWidth = (desc.Metrics.width / 64) + 1;
				int32 glyphHeight = (.)_fontSize + border;
				//int32 glyphHeight = (desc.Metrics.height / 64) + 1;

				// when size is 0 (1 because we added 1) the glyph has no image
				if(glyphWidth != border || glyphHeight != border)
				{
					//int32 glyphRight = penLeft + glyphWidth;

					int32 glyphRight = penLeft + glyphWidth + border;

					if(glyphRight > maxRes)
					{
						penLeft = 0;
						penTop += rowHeight;
						rowHeight = 0;
					}

					int32 glyphBottom = penTop + glyphHeight + border;

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
				//desc.SizeX = glyphWidth - 1;
				//desc.SizeY = glyphHeight - 1;
				desc.SizeX = (.)_fontSize;
				desc.SizeY = (.)_fontSize;

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

		public bool secondTime = false;

		void DrawAtlas()
		{
			Int32_3 oldAtlasSize = _atlasSize;
			_atlasSize = PrepareAtlas();

			if(_atlasSize != oldAtlasSize)
			{
				var oldAtlas = _atlas;

				Texture2DDesc desc;
				desc.Format = .R8G8B8A8_SNorm;
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

				DoTheThing(desc);

				desc.IsRendered = true;
			}
		}

		void DoTheThing(GlyphDescriptor desc)
		{
			// prepare shape
			
			double advance = 0;

			Shape shape;
			msdfgen.LoadGlyph(out shape, ref _face, desc.GlyphIndex, out advance);

			shape.Normalize();

			var bounds = shape.GetBounds();
			
			msdfgen.EdgeColoringSimple(shape, 3.0);

			// prepare projection

			int width;
			int height;
			
			double translationX;
			double translationY;

			if(bounds.Left < bounds.Right && bounds.Bottom < bounds.Top)
			{
				double l = bounds.Left;
				double r = bounds.Right;
				double b = bounds.Bottom;
				double t = bounds.Top;

				l -= 0.5 * _range;
				b -= 0.5 * _range;
				r += 0.5 * _range;
				t += 0.5 * _range;

				// TODO: miter?!

				double w = _geometryScaler * (r - l);
				double h = _geometryScaler * (t - b);

				width = (int)Math.Ceiling(w) + 1;
				height = (int)Math.Ceiling(h) + 1;

				translationX = -l + 0.5 * (width - w) / _geometryScaler;
				translationY = -b + 0.5 * (height - h) / _geometryScaler;
			}
			else
			{
				width = 0;
				height = 0;
				translationX = 0;
				translationY = 0;
			}

			msdfgen.Projection projection = .();
			projection.ScaleX = _geometryScaler;
			projection.ScaleY = _geometryScaler;

			projection.TranslationX = translationX;
			projection.TranslationY = translationY;

			/*

			void GlyphGeometry::wrapBox(double scale, double range, double miterLimit) {
			    scale *= geometryScale;
			    range /= geometryScale;
			    box.range = range;
			    box.scale = scale;
			    if (bounds.l < bounds.r && bounds.b < bounds.t) {
			        double l = bounds.l, b = bounds.b, r = bounds.r, t = bounds.t;
			        l -= .5*range, b -= .5*range;
			        r += .5*range, t += .5*range;
			        if (miterLimit > 0)
			            shape.boundMiters(l, b, r, t, .5*range, miterLimit, 1);
			        double w = scale*(r-l);
			        double h = scale*(t-b);
			        box.rect.w = (int) ceil(w)+1;
			        box.rect.h = (int) ceil(h)+1;
			        box.translate.x = -l+.5*(box.rect.w-w)/scale;
			        box.translate.y = -b+.5*(box.rect.h-h)/scale;
			    } else {
			        box.rect.w = 0, box.rect.h = 0;
			        box.translate = msdfgen::Vector2();
			    }
			}

			*/

			int x = _fontSize;
			int y = _fontSize;

			Bitmap<ColorRGB, const 1> bitmap = .((.)x, (.)y);

			MSDFGeneratorConfig config = .();

			msdfgen.GenerateMSDF(*(Bitmap<float, const 3>*)&bitmap, shape, projection, _range, config);
			
			int8[] pixels = new int8[x * y * 4];
			
			int8 ToInt8(float f) => (.)Math.Clamp(127f * f, int8.MinValue, int8.MaxValue);

			for(int iy = 0; iy < y; iy++)
			for(int ix = 0; ix < x; ix++)
			{
				ColorRGB pixel = bitmap.Pixels[iy * x + ix];

				int index = ((y - iy - 1) * x + ix) * 4;

				pixels[index + 0] = ToInt8(pixel.Red);
				pixels[index + 1] = ToInt8(pixel.Green);
				pixels[index + 2] = ToInt8(pixel.Blue);

				pixels[index + 3] = Int8.MaxValue;
			}

			_atlas.SetData<Color>((Color*)pixels.Ptr, (.)desc.MapCoord.X, (.)desc.MapCoord.Y,
				(.)desc.SizeX, (.)desc.SizeY, (.)desc.MapCoord.Z);
		}
	}
}
