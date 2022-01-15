using System;
using FreeType;
using GlitchyEngine.Math;
using GlitchyEngine.Core;
using System.Collections;
using msdfgen;
using System.Diagnostics;
using static FreeType.HarfBuzz;

using internal GlitchyEngine.Renderer.Text;

namespace GlitchyEngine.Renderer.Text
{
	public class Font : RefCounter
	{
		internal class GlyphDescriptor
		{
			public Font Font;

			public FT_UInt GlyphIndex;

			// TODO: Consider using floats
			public Int3 MapCoord;
			public int32 Width, Height;

			public double TranslationX, TranslationY;
			//public double Scale;

			/// How many pixels we have to move the pen after drawing this glyph.
			public float Advance;

			// Aligns the image of the glyph with the baseline
			public float AdjustToBaseLine;
			// Aligns the image of the glyph with the pen
			public float AdjustToPen;
			
			public bool IsBitmap;

			public bool IsCalculated = false;
			public bool IsRendered = false;
		}

		internal FT_Face _face ~ FreeType.Done_Face(_face);
		internal hb_font_t* _harfBuzzFont ~ hb_font_destroy(_);

		private Font _fallback ~ _?.ReleaseRef();

		internal uint32 _fontSize;
		private int32 _faceIndex;
		private bool _hasColor;
		
		private Int3 _penPos;
		private int32 _lastRowHeight;
		internal Texture2D _atlas ~ _?.ReleaseRef();
		private Int3 _atlasSize;

		private Dictionary<char32, GlyphDescriptor> _glyphs = new .() ~ delete _;//DeleteDictionaryAndValues!(_);
		private Dictionary<uint32, GlyphDescriptor> _glyphsById = new .() ~ DeleteDictionaryAndValues!(_);
		GlyphDescriptor _missingGlyph;
		
		private SamplerState _sampler ~ _.ReleaseRef();
		
		/// How much we have to scale the geometry to fit it into our desired pixels
		private double _geometryScaler;

		internal double _range = 4.0;

		/// The space between two lines.
		internal double _linespace;

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

		public this(String fontPath, uint32 fontSize, bool hasColor = true, char32 firstChar = '\0', uint32 charCount = 128, int32 faceIndex = 0)
		{
			Debug.Profiler.ProfileResourceFunction!();

			// Make sure the fontrenderer is initialized (Font only cares about freetype)
			FontRenderer.Init();

			// Set default sampler
			Sampler = null;

			_fontSize = fontSize;
			_faceIndex = faceIndex;
			_hasColor = hasColor;

			{
				Debug.Profiler.ProfileResourceScope!("Freetype.New_Face");

				FT_Error res = FreeType.New_Face(FontRenderer.s_Library, fontPath, faceIndex, &_face);
				Log.EngineLogger.Assert(res.Success, scope $"New_Face failed({(int)res}): {res}");
			}
			
			{
				Debug.Profiler.ProfileResourceScope!("Freetype.Set_Pixel_Sizes");

				FT_Error res = FreeType.Set_Pixel_Sizes(_face, 0, _fontSize);
				Log.EngineLogger.Assert(res.Success, scope $"Set_Pixel_Sizes failed({(int)res}): {res}");
			}

			double unitsPerEm = F26Dot6ToDouble(_face.units_per_EM);
			_geometryScaler = _fontSize / unitsPerEm;

			_range = 4.0 / _geometryScaler;

			_linespace = ((_face.size.metrics.ascender - _face.size.metrics.descender) / 64);

			GlyphDescriptor nullDesc = new GlyphDescriptor(){Font = this};
			nullDesc.GlyphIndex = FreeType.Get_Char_Index(_face, '\0');
			_glyphs.Add('\0', nullDesc);
			_glyphsById.Add(nullDesc.GlyphIndex, nullDesc);

			LoadGlyphs(firstChar, charCount);

			// HarfBuzz
			{
				Debug.Profiler.ProfileResourceScope!("hb_ft_font_create_referenced");

				_harfBuzzFont = hb_ft_font_create_referenced(_face);
				hb_font_set_scale(_harfBuzzFont, (.)fontSize * 64, (.)fontSize * 64);
			}

			//TestMSDF();
		}

		public void LoadGlyphs(char32 firstChar, uint32 charCount)
		{
			Debug.Profiler.ProfileResourceFunction!();

			ExtendRange(firstChar, firstChar + charCount);

			UpdateAtlas();
		}

		public void LoadGlyphs(uint32 firstGlyph, uint32 charCount)
		{
			Debug.Profiler.ProfileResourceFunction!();

			ExtendRange(firstGlyph, firstGlyph + charCount);

			UpdateAtlas();
		}

		/// Returns the font that can draw the char
		static internal Font GetDrawingFont(char32 char, Font font)
		{
			uint32 glyphId = FreeType.Get_Char_Index(font._face, char);

			if (glyphId != 0)
			{
				return font;
			}
			else if (font.Fallback != null)
			{		
				return GetDrawingFont(char, font.Fallback);
			}
			else
			{
				return null;
			}
		}

		internal GlyphDescriptor GetGlyph(uint32 glyphId, bool allowDynamicLoading = true)
		{
			GlyphDescriptor desc;

			if(_glyphsById.TryGetValue(glyphId, out desc))
			{
				// if the char is not defined in the current font try to load it from the fallback
				if(desc == null && _fallback != null)
				{
					desc = _fallback.GetGlyph(glyphId, allowDynamicLoading);
				}
			}
			else if(allowDynamicLoading)
			{
				// TODO: make reloading optional
				uint32 start = (glyphId >> 4) << 4;
				LoadGlyphs(start, 64);

				desc = GetGlyph(glyphId, false);
			}

			return desc ?? _missingGlyph;
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
			Debug.Profiler.ProfileResourceFunction!();

			// TODO: refactor

			for(char32 char = firstChar; char < rangeEnd; char++)
			{
				GlyphDescriptor desc = new GlyphDescriptor();
				if(_glyphs.TryAdd(char, desc))
				{
					//desc.Face = _face;
					desc.Font = this;
					desc.GlyphIndex = FreeType.Get_Char_Index(_face, char);
					
					_glyphsById.TryAdd(desc.GlyphIndex, desc);

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
		
		void ExtendRange(uint32 firstGlyph, uint32 rangeEnd)
		{
			Debug.Profiler.ProfileResourceFunction!();

			// TODO: refactor

			for(uint32 glyphId = firstGlyph; glyphId < rangeEnd; glyphId++)
			{
				GlyphDescriptor desc = new GlyphDescriptor();
				if(_glyphsById.TryAdd(glyphId, desc))
				{
					//desc.Face = _face;
					desc.Font = this;
					desc.GlyphIndex = glyphId;//FreeType.Get_Char_Index(_face, char);

					// if the char is not contained by the font we set the desc to null
					if(desc.GlyphIndex == 0)
					{
						delete desc;
						_glyphsById[glyphId] = null;
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
		private void RedrawAtlas()
		{
			for(let (char, desc) in _glyphs)
			{
				desc?.IsCalculated = false;
				desc?.IsRendered = false;
			}

			_penPos = .Zero;
			_lastRowHeight = 0;

			int8[] data = new int8[_atlas.Width * _atlas.Height * 4];

			_atlas.SetData<Color>((Color*)data.Ptr);

			UpdateAtlas();
		}

		Int3 PrepareAtlas()
		{
			Debug.Profiler.ProfileResourceFunction!();

			const uint32 maxRes = 16384; // D3D11_REQ_TEXTURE2D_U_OR_V_DIMENSION
			const uint32 maxArray = 2048; // D3D11_REQ_TEXTURE2D_ARRAY_AXIS_DIMENSION
			
			ref Int3 pen = ref _penPos;
			ref int32 rowHeight = ref _lastRowHeight;

			int32 atlasWidth = _atlasSize.X;
			int32 atlasHeight = _atlasSize.Y;
			int32 atlasArray = _atlasSize.Z;

			for(var (char, desc) in _glyphsById)
			{
				if(desc == null || desc.IsCalculated)
				{
					continue;
				}

				if(!Calculate(ref desc))
					continue;

				const int32 border = 1;

				if(desc.Width != 0 && desc.Height != 0)
				{
					int32 glyphRight = pen.X + desc.Width + border;

					if(glyphRight > maxRes)
					{
						pen.X = 0;
						pen.Y += rowHeight + border;
						rowHeight = 0;
					}

					int32 glyphBottom = pen.Y + desc.Height + border;

					if(glyphBottom > maxRes)
					{
						pen.X = 0;
						pen.Y = 0;
						rowHeight = 0;

						pen.Z++;
						
						if(pen.Z >= maxArray)
						{
							Log.EngineLogger.Error("Sprite font exceeded maximum texture size.");
						}
					}
				}

				desc.MapCoord = pen;
				
				if(desc.GlyphIndex == 0 && _missingGlyph == null)
				{
					_missingGlyph = desc;
				}

				pen.X += desc.Width + border;

				if (pen.X > atlasWidth)
				    atlasWidth = pen.X;

				if (desc.Height > rowHeight)
				    rowHeight = desc.Height;

				if (pen.Y + desc.Height > atlasHeight)
				    atlasHeight = pen.Y + desc.Height;

				if (pen.Z == atlasArray)
				    atlasArray++;

				desc.IsCalculated = true;
			}

			return .(atlasWidth, atlasHeight, atlasArray);
		}

		public bool secondTime = false;

		void DrawAtlas()
		{
			Debug.Profiler.ProfileResourceFunction!();

			Int3 oldAtlasSize = _atlasSize;
			_atlasSize = PrepareAtlas();

			if(_atlasSize != oldAtlasSize)
			{
				Debug.Profiler.ProfileResourceScope!("Recreate Atlas");

				var oldAtlas = _atlas;

				Texture2DDesc desc;
				desc.Format = .R8G8B8A8_SNorm;
				desc.MipLevels = 1;
				desc.Width = (.)_atlasSize.X;
				desc.Height = (.)_atlasSize.Y;
				desc.ArraySize = (.)_atlasSize.Z;
				desc.CpuAccess = .None;
				desc.Usage = .Default;

				_atlas = new Texture2D(desc);
				_atlas.SamplerState = _sampler;

				if(oldAtlas != null)
				{
					oldAtlas.CopyTo(_atlas);
					oldAtlas.ReleaseRef();
				}
			}

			for(let (char, desc) in _glyphsById)
			{
				if(desc == null)
					continue;

				var glyphIndex = desc.GlyphIndex;

				if(desc.IsRendered || glyphIndex == 0 || desc.Width == 0 || desc.Height == 0)
				{
					continue;
				}

				GenerateMSDF(desc);

				desc.IsRendered = true;
			}
		}

		bool Calculate(ref GlyphDescriptor desc)
		{
			Debug.Profiler.ProfileResourceFunction!();

			// prepare shape

			double advance = 0;

			Shape shape;

			{
				Debug.Profiler.ProfileResourceScope!("msdfgen.LoadGlyph");

				if(!msdfgen.LoadGlyph(out shape, ref _face, desc.GlyphIndex, out advance) || !shape.Validate())
				{
					return false;
				}
			}

			desc.Advance = (float)(advance * _geometryScaler);

			//shape.OrientContours();
			{
				Debug.Profiler.ProfileResourceScope!("msdfgen.ResolveShapeGeometry");

				msdfgen.ResolveShapeGeometry(shape);
			}

			shape.Normalize();

			var bounds = shape.GetBounds();
			
			// prepare projection

			double width;
			double height;

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
				
				// TODO: miter?
				//if (miterLimit > 0)
				//    shape.boundMiters(l, b, r, t, .5*range, miterLimit, 1);

				double w = _geometryScaler * (r - l);
				double h = _geometryScaler * (t - b);

				width = Math.Ceiling(w) + 1;
				height = Math.Ceiling(h) + 1;

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

			desc.Width = (.)width;
			desc.Height = (.)height;

			desc.TranslationX = translationX;
			desc.TranslationY = translationY;

			//desc.Scale = scale;

			desc.AdjustToBaseLine = (float)(-translationY * _geometryScaler);

			desc.AdjustToPen = (float)(-translationX);

			return true;
		}

		/*
		void TestMSDF()
		{
			GlyphDescriptor desc = scope .();
			desc.GlyphIndex = FreeType.Get_Char_Index(_face, 'A');

			var v = _range;

			_range = 4.0f;
			_geometryScaler = 1.0f;

			Calculate(ref desc);

			// prepare shape

			double advance = 0;

			Shape shape;
			msdfgen.LoadGlyph(out shape, ref _face, 36, out advance);
			
			bool b = msdfgen.ResolveShapeGeometry(shape);

			if(!b)
			{

			}

			shape.Normalize();

			var bounds = shape.GetBounds();

			//shape.ReverseIfNeeded(bounds);

			msdfgen.EdgeColoringSimple(shape, 3.0);

			// prepare projection
			msdfgen.Projection projection = .();
			projection.ScaleX = _geometryScaler;
			projection.ScaleY = _geometryScaler;

			projection.TranslationX = desc.TranslationX;
			projection.TranslationY = desc.TranslationY;

			int bufferX = desc.Width;
			int bufferY = desc.Height;

			using(Bitmap<ColorRGB, const 1> bitmap = .((.)bufferX, (.)bufferY))
			{
				MSDFGeneratorConfig config = .();

				msdfgen.GenerateMSDF(*(Bitmap<float, const 3>*)&bitmap, shape, projection, _range, config);

				// Check if we have to invert
				/*
				Line 1039
				// Get sign of signed distance outside bounds
				Point2 p(bounds.l-(bounds.r-bounds.l)-1, bounds.b-(bounds.t-bounds.b)-1);
				double distance = SimpleTrueShapeDistanceFinder::oneShotDistance(shape, p);
				orientation = distance <= 0 ? KEEP : REVERSE;

				if (invert)
				{
					invertColor<3>(bitmap);
				}
				*/

				uint8[] pixels = new:ScopedAlloc! uint8[desc.Width * desc.Height * 4];
				
				//int8 ToInt8(float f) => (.)Math.Clamp(127f * f, int8.MinValue, int8.MaxValue);
				uint8 ToInt8(float f) => (.)Math.Clamp(255 * f, uint8.MinValue, uint8.MaxValue);

				for(int y = 0; y < desc.Height; y++)
				for(int x = 0; x < desc.Width; x++)
				{
					ColorRGB pixel = bitmap.Pixels[(y) * bufferX + x];

					int index = ((desc.Height - y - 1) * desc.Width + x) * 4;

					pixels[index + 0] = ToInt8(pixel.Red);
					pixels[index + 1] = ToInt8(pixel.Green);
					pixels[index + 2] = ToInt8(pixel.Blue);

					pixels[index + 3] = uint8.MaxValue;
				}

				LodePng.LodePng.Encode32File("testA.png", pixels.CArray(), (.)desc.Width, (.)desc.Height);

				//_atlas.SetData<Color>((Color*)pixels.Ptr, (.)desc.MapCoord.X, (.)desc.MapCoord.Y,
				//	(.)desc.Width, (.)desc.Height, (.)desc.MapCoord.Z);
			}

			_range = v;
		}
		*/

		void GenerateMSDF(GlyphDescriptor desc)
		{
			Debug.Profiler.ProfileResourceFunction!();

			// prepare shape
			
			double advance = 0;

			Shape shape;
			
			{
				Debug.Profiler.ProfileResourceScope!("msdfgen.LoadGlyph");
				
				msdfgen.LoadGlyph(out shape, ref _face, desc.GlyphIndex, out advance);
			}
			
			msdfgen.ResolveShapeGeometry(shape);

			shape.Normalize();

			//var bounds = shape.GetBounds();
			
			//shape.ReverseIfNeeded(bounds);

			msdfgen.EdgeColoringSimple(shape, 3.0);

			// prepare projection
			msdfgen.Projection projection = .();
			projection.ScaleX = _geometryScaler;
			projection.ScaleY = _geometryScaler;

			projection.TranslationX = desc.TranslationX;
			projection.TranslationY = desc.TranslationY;

			int bufferX = desc.Width;
			int bufferY = desc.Height;

			using(Bitmap<ColorRGB, const 1> bitmap = .((.)bufferX, (.)bufferY))
			{
				Debug.Profiler.ProfileResourceScope!("GenerateMSDF");
				
				MSDFGeneratorConfig config = .();
	
				msdfgen.GenerateMSDF(*(Bitmap<float, const 3>*)&bitmap, shape, projection, _range, config);
				
				int8[] pixels = new:ScopedAlloc! int8[desc.Width * desc.Height * 4];
				
				int8 ToInt8(float f) => (.)Math.Clamp(127f * f, int8.MinValue, int8.MaxValue);
	
				for(int y = 0; y < desc.Height; y++)
				for(int x = 0; x < desc.Width; x++)
				{
					ColorRGB pixel = bitmap.Pixels[(y) * bufferX + x];
	
					int index = ((desc.Height - y - 1) * desc.Width + x) * 4;
	
					pixels[index + 0] = ToInt8(pixel.Red);
					pixels[index + 1] = ToInt8(pixel.Green);
					pixels[index + 2] = ToInt8(pixel.Blue);
	
					pixels[index + 3] = Int8.MaxValue;
				}
	
				_atlas.SetData<Color>((Color*)pixels.Ptr, (.)desc.MapCoord.X, (.)desc.MapCoord.Y,
					(.)desc.Width, (.)desc.Height, (.)desc.MapCoord.Z);
			}
		}
	}
}
