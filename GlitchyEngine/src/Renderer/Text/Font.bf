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
			public int3 MapCoord;
			public int32 Width, Height;

			public double TranslationX, TranslationY;

			/**
			 * The size of the quad that has to be drawn for this glyph. (In em)
			 * Multiply with the desired font size (in world units) to get the actual size of the quad.
			 * @remarks The quad is larger than the visible ink of the glyph, because the box also contains the MSDF-distance range and the padding.
			 */
			public double2 QuadSizeEm;

			public Shape* Shape;

			/// How far we have to move the pen after drawing this glyph. (In em)
			public float Advance;

			/// Aligns the image of the glyph with the baseline: offset from the baseline to the bottom edge of the quad. (In em, Y points up)
			public float AdjustToBaseLine;
			/// Aligns the image of the glyph with the pen: offset from the pen position to the left edge of the quad. (In em)
			public float AdjustToPen;
			
			public bool IsBitmap;

			public bool IsCalculated = false;
			public bool IsRendered = false;

			public msdfgen.Range boxRange;
			public double boxScale;
			public msdfgen.Rectangle boxRect;
			public double2 boxTranslate;
			public Padding boxOuterPadding;
		}

		// TODO: I don't understand why freeing the face and hb_font sometimes results in an access violation...
		internal FT_Face _face;// ~ FreeType.Done_Face(_face);//TODO!: ~ FreeType.Done_Face(_face);
		internal hb_font_t* _harfBuzzFont;// ~ hb_font_destroy(_);//TODO:!! ~ hb_font_destroy(_);
		internal hb_face_t* _harfBuzzFace;// ~ hb_face_destroy(_);//TODO:!! ~ hb_font_destroy(_);

		private Font _fallback ~ _?.ReleaseRef();

		//internal uint32 _fontSize;
		private int32 _faceIndex;
		private bool _hasColor;
		
		private int3 _penPos;
		private int32 _lastRowHeight;
		internal Texture2D _atlas ~ _?.ReleaseRef();
		private int3 _atlasSize;

		private Dictionary<char32, GlyphDescriptor> _glyphs = new .() ~ delete _;//DeleteDictionaryAndValues!(_);
		private Dictionary<uint32, GlyphDescriptor> _glyphsById = new .() ~ DeleteDictionaryAndValues!(_);
		GlyphDescriptor _missingGlyph;
		
		private SamplerState _sampler ~ _.ReleaseRef();
		
		/// How much we have to scale the geometry to fit it into our desired pixels
		private double _geometryScale;

		/// The scale at which the glyphs are rasterized into the atlas. (In pixels per em)
		internal double _atlasPixelsPerEm;

		/// The width of the MSDF-distance range that is baked into the atlas. (In atlas pixels)
		/// The MSDF-shader needs this value in order to determine how many pixels on screen the distance range covers.
		internal double _atlasPxRange;

		///
		//	Font Units
	  	///

		/// The number of units per em. This is the precision that the font has been designed with internally.
		internal double _unitsPerEm;

		/// The space between two lines when rendering horizontal text. (In Font Units (em))
		internal double _linespaceEmHorizontal;

		/// The space between two lines when rendering vertical text. (In Font Units (em))
		internal double _linespaceEmVertical;

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

		public this(String fontPath, bool hasColor = true, char32 firstChar = '\0', uint32 charCount = 128, int32 faceIndex = 0)
		{
			Debug.Profiler.ProfileResourceFunction!();

			// Set default sampler
			Sampler = null;

			//_fontSize = fontSize;
			_faceIndex = faceIndex;
			_hasColor = hasColor;

			{
				Debug.Profiler.ProfileResourceScope!("Freetype.New_Face");

				FT_Error res = FreeType.New_Face(FontRenderer.s_Library, fontPath, faceIndex, &_face);
				Log.EngineLogger.Assert(res.Success, scope $"New_Face failed({(int)res}): {res}");
			}
			
			{
				Debug.Profiler.ProfileResourceScope!("Freetype.Set_Pixel_Sizes");

				// We must set a size for Harfbuzz to work. But we actually don't care about pixels (because we use MSDFGen)
				// So we just use units per EM
				FT_Error res = FreeType.Set_Char_Size(_face, 0, _face.units_per_EM, 0, 0);
				Log.EngineLogger.Assert(res.Success, scope $"Set_Pixel_Sizes failed({(int)res}): {res}");
			}

			// HarfBuzz
			{
				Debug.Profiler.ProfileResourceScope!("hb_ft_font_create_referenced");

				_harfBuzzFont =  hb_ft_font_create_referenced(_face);
				_harfBuzzFace = hb_font_get_face(_harfBuzzFont);

				_unitsPerEm = hb_face_get_upem(_harfBuzzFace);
				hb_font_set_scale(_harfBuzzFont, (.)_unitsPerEm, (.)_unitsPerEm);
				
				/*hb_font_extents_t horizontalExtends = .();
				hb_font_get_h_extents(_harfBuzzFont, &horizontalExtends);
				hb_font_extents_t verticalExtends = .();
				hb_font_get_v_extents(_harfBuzzFont, &verticalExtends);

				_linespaceEmHorizontal = horizontalExtends.ascender - horizontalExtends.descender + horizontalExtends.line_gap;
				_linespaceEmVertical = verticalExtends.ascender - verticalExtends.descender + verticalExtends.line_gap;*/
			}

			// TODO: FontScale != font size
			const double fontScale = 1.0;

			// geometryScale is an MSDFgen specific value
			// MSDFgen works directly with the freetype face thus we use the value form the freetype face there,
			// even though it should always be as hb_face_get_upem.
			_geometryScale = fontScale / _face.units_per_EM;
			
			_linespaceEmHorizontal = _face.height * _geometryScale;

			GlyphDescriptor nullDesc = new GlyphDescriptor(){Font = this};
			nullDesc.GlyphIndex = FreeType.Get_Char_Index(_face, '\0');
			_glyphs.Add('\0', nullDesc);
			_glyphsById.Add(nullDesc.GlyphIndex, nullDesc);

			LoadGlyphs(firstChar, charCount);

			// MSDF-Stuff:
			// metrics.emSize = font->face->units_per_EM * _geometryScaler;
			// metrics.ascenderY = font->face->ascender * _geometryScaler;
			// metrics.descenderY = font->face->descender * _geometryScaler;
			// metrics.lineHeight = font->face->height * _geometryScaler;
			// metrics.underlineY = font->face->underline_position * _geometryScaler;
			// metrics.underlineThickness = font->face->underline_thickness * _geometryScaler;
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
		internal Font GetDrawingFont(char32 char)
		{
			uint32 glyphId = FreeType.Get_Char_Index(_face, char);

			if (glyphId != 0)
			{
				return this;
			}
			else if (Fallback != null)
			{		
				return Fallback.GetDrawingFont(char);
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

		int3 PrepareAtlas(GlyphAttributes attribs)
		{
			Debug.Profiler.ProfileResourceFunction!();

			const uint32 maxRes = 16384; // D3D11_REQ_TEXTURE2D_U_OR_V_DIMENSION
			const uint32 maxArray = 2048; // D3D11_REQ_TEXTURE2D_ARRAY_AXIS_DIMENSION
			
			ref int3 pen = ref _penPos;
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

				if(!CalculateGlyphBox(ref desc, attribs))
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

			// Pixels per Em
			double scale = 64.0;
			
			// TODO: Default values from MSDF-Atlas-Gen
			msdfgen.Range unitRange = .(0.0, 0.0);
			msdfgen.Range pxRange = .(-1.0, 1.0);
    		Padding innerUnitPadding = .(0);
			Padding outerUnitPadding = .(0);
    		Padding innerPxPadding = .(0);
			Padding outerPxPadding = .(0);
			double miterLimit = 1.0;
			bool2 pxAlignOrigin = .(false, true);
			

			GlyphAttributes attribs = .();
			attribs.Scale = scale;
			attribs.Range = unitRange + pxRange / scale;
			attribs.InnerPadding = innerUnitPadding + innerPxPadding / scale;
			attribs.OuterPadding = outerUnitPadding + outerPxPadding / scale;
			attribs.MiterLimit = miterLimit;
			attribs.PxAlignOrigin = pxAlignOrigin;

			// Derive the atlas metrics that the renderer and the MSDF-shader need from the attributes we just rasterize with,
			// so that they stay in sync if scale or range are ever changed.
			_atlasPixelsPerEm = attribs.Scale;
			_atlasPxRange = (attribs.Range.Upper - attribs.Range.Lower) * attribs.Scale;

			// TODO: Ohne die hier geht nichts!
			/*attribs.scale = scale;
			attribs.range = unitRange+pxRange/scale;
			attribs.innerPadding = innerUnitPadding+innerPxPadding/scale;
			attribs.outerPadding = outerUnitPadding+outerPxPadding/scale;
			attribs.miterLimit = miterLimit;
			attribs.pxAlignOriginX = pxAlignOriginX;
			attribs.pxAlignOriginY = pxAlignOriginY;*/

			int3 oldAtlasSize = _atlasSize;
			_atlasSize = PrepareAtlas(attribs);

			if(any(_atlasSize != oldAtlasSize))
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

				_atlas.Identifier = scope $"Font Atlas - {StringView(_face.family_name)} {StringView(_face.style_name)}";
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

		struct GlyphAttributes
		{
			public double Scale;
			public msdfgen.Range Range;
			public msdfgen.Padding InnerPadding, OuterPadding;
			public double MiterLimit;
			public bool2 PxAlignOrigin;
		}
		
		/**
		 * Calculates the bounding box in pixels around the 
		 */
		bool CalculateGlyphBox(ref GlyphDescriptor desc, GlyphAttributes glyphAttributes)
		{
			Debug.Profiler.ProfileResourceFunction!();

			// prepare shape

			double advance = 0;

			//Shape* shape;

			//defer { msdfgen.DestroyShape(shape); }

			{
				Debug.Profiler.ProfileResourceScope!("msdfgen.LoadGlyph");

				// TODO: load in LoadGlyphs-Method, not here!
				if (desc.Shape == null && !msdfgen.LoadGlyph(out desc.Shape, ref _face, desc.GlyphIndex, .FONT_SCALING_NONE, out advance))
				{
					return false;
				}

				if(!Shape.Validate(desc.Shape))
				{
					return false;
				}
			}

			desc.Advance = (float)(advance * _geometryScale);

			Shape.Normalize(desc.Shape);

			var bounds = Shape.GetBounds(desc.Shape);
			// TODO: Save shapes and bounds in desc?

			// msdfgen's geometry preprocessing needs Skia, which this build doesn't have, so we do what msdf-atlas-gen
			// does in that case: determine if the shape is winded incorrectly and reverse it in that case.
			// Reversing the contours doesn't change the bounding box, so bounds stays valid.
			Shape.ReverseIfNeeded(desc.Shape, bounds);

			// TODO: Ohne korrekten _geometryScaler läuft hier garnüscht.
			double scale = glyphAttributes.Scale * _geometryScale;
			msdfgen.Range range = glyphAttributes.Range / _geometryScale;
			Padding fullPadding = (glyphAttributes.InnerPadding + glyphAttributes.OuterPadding) / _geometryScale;

			desc.boxRange = range;
			desc.boxScale = scale;
			/*msdfgen.Range boxRange = range;
			double boxScale = scale;
			msdfgen.Rectangle boxRect;
			double2 boxTranslate;
			Padding boxOuterPadding;*/

			if (bounds.Left < bounds.Right && bounds.Bottom < bounds.Top)
			{
			    double l = bounds.Left, b = bounds.Bottom, r = bounds.Right, t = bounds.Top;
			    l += range.Lower;
				b += range.Lower;
			    r -= range.Lower;
				t -= range.Lower;

			    if (glyphAttributes.MiterLimit > 0)
				{
					// TODO: Does this have to be a static function?
			        Shape.BoundMiters(desc.Shape, ref l, ref b, ref r, ref t, -range.Lower, glyphAttributes.MiterLimit, 1);
				}

			    l -= fullPadding.Left;
				b -= fullPadding.Bottom;
			    r += fullPadding.Right;
				t += fullPadding.Top;

			    if (glyphAttributes.PxAlignOrigin.X)
				{
			        int sl = (int) Math.Floor(scale * l - 0.5);
			        int sr = (int) Math.Ceiling(scale * r + 0.5);
			        desc.boxRect.Width = sr - sl;
			        desc.boxTranslate.X = -sl/scale;
			    }
				else
				{
			        double w = scale*(r-l);
			        desc.boxRect.Width = (int) Math.Ceiling(w) + 1;
			        desc.boxTranslate.X = -l + 0.5 * (desc.boxRect.Width - w) / scale;
			    }

			    if (glyphAttributes.PxAlignOrigin.Y)
				{
			        int sb = (int) Math.Floor(scale * b - 0.5);
			        int st = (int) Math.Ceiling(scale * t + 0.5);
			        desc.boxRect.Height = st-sb;
			        desc.boxTranslate.Y = -sb/scale;
			    }
				else
				{
			        double h = scale * (t - b);
			        desc.boxRect.Height = (int) Math.Ceiling(h) + 1;
			        desc.boxTranslate.Y = -b + 0.5 * (desc.boxRect.Height - h) / scale;
			    }

			    desc.boxOuterPadding = glyphAttributes.Scale * glyphAttributes.OuterPadding;
			}
			else
			{
			    desc.boxRect.Width = 0;
				desc.boxRect.Height = 0;
			    desc.boxTranslate = 0;
			}

			desc.Width = (int32)desc.boxRect.Width;
			desc.Height = (int32)desc.boxRect.Height;

			// The glyph is rasterized with glyphAttributes.Scale pixels per em, so dividing the pixel size of the box
			// by that factor gives us the size of the quad in em. (Empty shapes have a zero-sized box and thus a zero-sized quad.)
			desc.QuadSizeEm = .((double)desc.boxRect.Width  / glyphAttributes.Scale,
								(double)desc.boxRect.Height / glyphAttributes.Scale);

			// The projection maps a coordinate c to (c + boxTranslate) * scale, so pixel 0 of the box corresponds to
			// c = -boxTranslate. That is the left/bottom edge of the box in font units, _geometryScale turns it into em.
			desc.AdjustToBaseLine = (float)(-desc.boxTranslate.Y * _geometryScale);
			desc.AdjustToPen = (float)(-desc.boxTranslate.X * _geometryScale);

			return true;
		}

		/**
		 * Calculates the bounding box in pixels around the 
		 */
		bool CalculateGlyphBoxOld(ref GlyphDescriptor desc, GlyphAttributes attribs)
		{
			Debug.Profiler.ProfileResourceFunction!();

			// prepare shape

			double advance = 0;

			Shape* shape;

			defer { msdfgen.DestroyShape(shape); }
			
			{
				Debug.Profiler.ProfileResourceScope!("msdfgen.LoadGlyph");

				if(!msdfgen.LoadGlyph(out shape, ref _face, desc.GlyphIndex, .FONT_SCALING_NONE, out advance) || !Shape.Validate(shape))
				{
					return false;
				}
			}
				
			desc.Advance = (float)(advance * _geometryScale);

			// No Skia, no ResolveShapeGeometry :/
			//if (preprocessGeometry)
			//{
			//	Debug.Profiler.ProfileResourceScope!("msdfgen.ResolveShapeGeometry");

			//	msdfgen.ResolveShapeGeometry(shape);
			//}

			Shape.Normalize(shape);
			
			var bounds = Shape.GetBounds(shape);
			// TODO: Save shapes and bounds in desc?

			//if (!preprocessGeometry)
			{
				// TODO!
			    // Determine if shape is winded incorrectly and reverse it in that case
				//double2 outerPoint = .(bounds.Left - (bounds.Right - bounds.Left) - 1.0, bounds.Bottom - (bounds.Top - bounds.Bottom) - 1.0);
			    //if (msdfgen::SimpleTrueShapeDistanceFinder::oneShotDistance(shape, outerPoint) > 0) {
			    //    for (msdfgen::Contour &contour : shape.contours)
			    //        contour.reverse();
			    //}
			}




			/*
			// prepare projection

			double width;
			double height;

			double translationX;
			double translationY;

			/*
			#define DEFAULT_SIZE 32.0
			#define DEFAULT_ANGLE_THRESHOLD 3.0
			#define DEFAULT_MITER_LIMIT 1.0
			#define DEFAULT_PIXEL_RANGE 2.0
			#define SDF_ERROR_ESTIMATE_PRECISION 19
			*/

			//double scale = glyphAttributes.scale*geometryScale;
			double scale = _geometryScaler;

			msdfgen.Range range = Range(_range);

			//Padding fullPadding = (glyphAttributes.innerPadding+glyphAttributes.outerPadding)/geometryScale;
			//box.range = range;
			//box.scale = scale;
			if(bounds.Left < bounds.Right && bounds.Bottom < bounds.Top)
			{
				double l = bounds.Left;
				double r = bounds.Right;
				double b = bounds.Bottom;
				double t = bounds.Top;
				
				l -= range.Upper;
				b -= range.Upper;
				r += range.Upper;
				t += range.Upper;

				// TODO: Miter
			    //if (glyphAttributes.miterLimit > 0)
			    //    shape.boundMiters(l, b, r, t, -range.lower, glyphAttributes.miterLimit, 1);

				// TODO: Padding
			    //l -= fullPadding.l, b -= fullPadding.b;
			    //r += fullPadding.r, t += fullPadding.t;

			    /*if (glyphAttributes.pxAlignOriginX) {
			        int sl = (int) floor(scale*l-.5);
			        int sr = (int) ceil(scale*r+.5);
			        box.rect.w = sr-sl;
			        box.translate.x = -sl/scale;
			    } else {
			        double w = scale*(r-l);
			        box.rect.w = (int) ceil(w)+1;
			        box.translate.x = -l+.5*(box.rect.w-w)/scale;
			    }
			    if (glyphAttributes.pxAlignOriginY) {
			        int sb = (int) floor(scale*b-.5);
			        int st = (int) ceil(scale*t+.5);
			        box.rect.h = st-sb;
			        box.translate.y = -sb/scale;
			    } else {
			        double h = scale*(t-b);
			        box.rect.h = (int) ceil(h)+1;
			        box.translate.y = -b+.5*(box.rect.h-h)/scale;
			    }*/
				
				double w = scale * (r - l);
				width = (int) Math.Ceiling(w) + 1;
				translationX = -l + 0.5 * (width - w) / scale;
				
				double h = scale * (t - b);
				height = (int) Math.Ceiling(h) + 1;
				translationY = -b + 0.5 * (height - h) / scale;

				// TODO: Outer padding?
			    //box.outerPadding = glyphAttributes.scale*glyphAttributes.outerPadding;
			} else {
				width = 0;
				height = 0;
				translationX = 0;
				translationY = 0;
			}


			/*if(bounds.Left < bounds.Right && bounds.Bottom < bounds.Top)
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

				//double w = _geometryScaler * (r - l);
				//double h = _geometryScaler * (t - b);

				width = 32 ;//* (bounds.Right - bounds.Left);//_fontSize; //Math.Ceiling(w) + 1;
				height = 32;// * (bounds.Top - bounds.Bottom);//_fontSize; //Math.Ceiling(h) + 1;

				translationX = 0;//-l + 0.5 * (width - width) / _geometryScaler;
				translationY = 0;//-b + 0.5 * (height - height) / _geometryScaler;
			}
			else
			{
				width = 0;
				height = 0;
				translationX = 0;
				translationY = 0;
			}*/

			desc.Width = (.)width;
			desc.Height = (.)height;

			desc.TranslationX = translationX;
			desc.TranslationY = translationY;

			//desc.Scale = scale;

			desc.AdjustToBaseLine = (float)(-translationY * _geometryScaler);

			desc.AdjustToPen = (float)(-translationX);*/

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

			// The shape is already normalized and preprocessed by CalculateGlyphBox and isn't touched inbetween,
			// so all that's left to do here is coloring the edges.
			msdfgen.EdgeColoringSimple(desc.Shape, 3.0);

			// prepare projection
			SDFTransformation t = SDFTransformation(Projection(desc.boxScale, desc.boxScale, desc.boxTranslate.X, desc.boxTranslate.Y), DistanceMapping(desc.boxRange));

			int bufferX = desc.Width;
			int bufferY = desc.Height;

			using(Bitmap<ColorRGB, const 1> bitmap = .((.)bufferX, (.)bufferY, .Y_DOWNWARD))
			{
				Debug.Profiler.ProfileResourceScope!("GenerateMSDF");

				// Default config seems to be fine
				MSDFGeneratorConfig config = .();
				msdfgen.GenerateMSDF(*(Bitmap<float, const 3>*)&bitmap, desc.Shape, t, config);
				
				int8[] pixels = new:ScopedAlloc! int8[desc.Width * desc.Height * 4];
				
				int8 ToInt8(float f) => (.)Math.Clamp(127f * f, int8.MinValue, int8.MaxValue);

				for(int y = 0; y < desc.Height; y++)
				for(int x = 0; x < desc.Width; x++)
				{
					ColorRGB pixel = bitmap.Pixels[(y) * bufferX + x];

					int index = (y * desc.Width + x) * 4;

					pixels[index + 0] = ToInt8(pixel.R);
					pixels[index + 1] = ToInt8(pixel.G);
					pixels[index + 2] = ToInt8(pixel.B);

					pixels[index + 3] = Int8.MaxValue;
				}

				_atlas.SetData<Color>((Color*)pixels.Ptr, (.)desc.MapCoord.X, (.)desc.MapCoord.Y,
					(.)desc.Width, (.)desc.Height, (.)desc.MapCoord.Z);
			}
		}

		void GenerateMSDFOld(GlyphDescriptor desc)
		{
			Debug.Profiler.ProfileResourceFunction!();

			// prepare shape
			
			double advance = 0;

			Shape* shape;

			defer { msdfgen.DestroyShape(shape); }
			
			{
				Debug.Profiler.ProfileResourceScope!("msdfgen.LoadGlyph");
				
				msdfgen.LoadGlyph(out shape, ref _face, desc.GlyphIndex, .FONT_SCALING_EM_NORMALIZED, out advance);
			}
			
			msdfgen.ResolveShapeGeometry(shape);

			Shape.Normalize(shape);

			msdfgen.EdgeColoringSimple(shape, 3.0);

			// prepare projection
			SDFTransformation t = SDFTransformation(Projection(32.0, 32.0, 0.125, 0.125), DistanceMapping(msdfgen.Range(0.125)));

			int bufferX = desc.Width;
			int bufferY = desc.Height;

			using(Bitmap<ColorRGB, const 1> bitmap = .((.)bufferX, (.)bufferY, .Y_DOWNWARD))
			{
				Debug.Profiler.ProfileResourceScope!("GenerateMSDF");
				
				MSDFGeneratorConfig config = .();
	
				msdfgen.GenerateMSDF(*(Bitmap<float, const 3>*)&bitmap, shape, t, config);
				
				int8[] pixels = new:ScopedAlloc! int8[desc.Width * desc.Height * 4];
				
				int8 ToInt8(float f) => (.)Math.Clamp(127f * f, int8.MinValue, int8.MaxValue);
	
				for(int y = 0; y < desc.Height; y++)
				for(int x = 0; x < desc.Width; x++)
				{
					ColorRGB pixel = bitmap.Pixels[(y) * bufferX + x];
	
					int index = (y * desc.Width + x) * 4;
	
					pixels[index + 0] = ToInt8(pixel.R);
					pixels[index + 1] = ToInt8(pixel.G);
					pixels[index + 2] = ToInt8(pixel.B);
	
					pixels[index + 3] = Int8.MaxValue;
				}
	
				_atlas.SetData<Color>((Color*)pixels.Ptr, (.)desc.MapCoord.X, (.)desc.MapCoord.Y,
					(.)desc.Width, (.)desc.Height, (.)desc.MapCoord.Z);
			}
			// The shape is no longer needed
			msdfgen.DestroyShape(desc.Shape);
			desc.Shape = null;
		}
	}
}
