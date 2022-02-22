using System;
using FreeType;
using System.Diagnostics;
using GlitchyEngine.Math;
using System.Collections;
using static FreeType.HarfBuzz;

using internal GlitchyEngine.Renderer.Text;
using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer.Text
{
	public static class FontRenderer
	{
		internal static FT_Library s_Library;

		public static Effect _msdfEffect;

		internal static bool s_isInitialized;

		internal static void Init()
		{
			Debug.Profiler.ProfileFunction!();

			if(s_isInitialized)
				return;

			InitFreetype();

			_msdfEffect = new Effect("content\\Shaders\\msdfShader.hlsl");

			s_isInitialized = true;
		}

		internal static void Deinit()
		{
			Debug.Profiler.ProfileFunction!();

			_msdfEffect.ReleaseRef();

			DeinitFreetype();
			
			s_isInitialized = false;
		}
		
		private static void InitFreetype()
		{
			Debug.Profiler.ProfileFunction!();

			if(s_Library == null)
			{
				var res = FreeType.Init_FreeType(&s_Library);
				Log.EngineLogger.Assert(res.Success, scope $"Failed to initialize freetype ({(int)res}): {res}");
			}
		}

		private static void DeinitFreetype()
		{
			Debug.Profiler.ProfileFunction!();

			FreeType.Done_FreeType(s_Library);
		}

		public class PreparedText : RefCounted
		{
			//public List<PreparedLine> Lines ~ ClearAndDeleteItems!(_);
			public Font Font ~ _?.ReleaseRef();
			public List<PreparedGlyph> Glyphs ~ delete:append _;

			public float AdvanceX;
			public float AdvanceY;

			[AllowAppend]
			public this(Font font)
			{
				//List<PreparedLine> lines = append .();
				//Lines = lines;
				List<PreparedGlyph> glyphs = append .();
				Glyphs = glyphs;

				if(font != null)
					Font = font..AddRef();
			}

			public static readonly Self Empty = new Self(null) ~ _.ReleaseRef();
		}
		/*
		public class PreparedLine
		{
			public int Line;
			public List<PreparedGlyph> Glyphs;
			
			[AllowAppend]
			public this()
			{
				List<PreparedGlyph> glyphs = append .();
				Glyphs = glyphs;
			}
		}
		*/
		public struct PreparedGlyph
		{
			public Font Font;
			public uint32 GlyphId;
			public Vector2 Position;
			public float Scale;
			//public float AdvanceX;
			//public float AdvanceY;

			public this(Font font, uint32 glyphId, Vector2 position, float scale)//, float advanceX, float advanceY)
			{
				Font = font;
				GlyphId = glyphId;
				Position = position;
				Scale = scale;
				//AdvanceX = advanceX;
				//AdvanceY = advanceY;
			}
		}

		public enum TextDirection
		{
			case LeftToRight;
			case RightToLeft;
			case TopToBottom;
			case BottomToTop;
		}

		public static PreparedText PrepareText(Font font, String text, float fontSize, Color fontColor = .White, Color bitmapColor = .White, float lineSpaceScale = 1.0f, TextDirection direction = .LeftToRight)
		{
			Debug.Profiler.ProfileRendererFunction!();

			PreparedText preparedText = new PreparedText(font);

			float scale = fontSize / (float)font._fontSize;
			
			// Space between two baselines
			float linespace = (float)font._linespace * lineSpaceScale * scale;
			
			// The line we are writing on
			float baseline = 0;
			
			// Position of the next character on the line
			float penPosition = 0;

			// TODO: use stringview?
			StringView textBuffer = .(text, 0, 0);//new:ScopedAlloc! String();
			
			hb_buffer_t* buf = hb_buffer_create();

			//PreparedLine currentLine = new PreparedLine();

			// Stack to keep track of the text direction.
			List<TextDirection> textDirectionStack = scope .();
			textDirectionStack.Add(direction);
			
			int movedLines = 0;

			Font currentFont = font;

			int currentIndex = 0;

			void FlushShapeBuffer()
			{
				Debug.Profiler.ProfileRendererFunction!();

				float fontScale = (float)fontSize / currentFont._fontSize;

				hb_buffer_clear_contents(buf);

				hb_buffer_add_utf8(buf, text.Ptr, (.)text.Length, (.)(textBuffer.Ptr - text.Ptr), (.)textBuffer.Length);
				
				textBuffer.Ptr += textBuffer.Length;
				textBuffer.Length = 0;

				// Set the script, language and direction of the buffer.
				// TODO: change direction, script, etc.

				TextDirection direction = textDirectionStack.Back;

				switch (direction)
				{
				case .LeftToRight:
					hb_buffer_set_direction(buf, .HB_DIRECTION_LTR);
				case .RightToLeft:
					hb_buffer_set_direction(buf, .HB_DIRECTION_RTL);
				case .TopToBottom:
					hb_buffer_set_direction(buf, .HB_DIRECTION_TTB);
				case .BottomToTop:
					hb_buffer_set_direction(buf, .HB_DIRECTION_BTT);
				}

				hb_buffer_set_script(buf, .HB_SCRIPT_LATIN);
				hb_buffer_set_language(buf, hb_language_from_string("en".CStr(), -1));
				
				hb_shape(currentFont._harfBuzzFont, buf, null, 0);

				
				// 5. Get the glyph and position information.
				uint32 glyph_count = ?;
				hb_glyph_info_t* glyph_info    = hb_buffer_get_glyph_infos(buf, &glyph_count);
				hb_glyph_position_t* glyph_pos = hb_buffer_get_glyph_positions(buf, &glyph_count);

				for (uint32 i < glyph_count)
				{
					hb_codepoint_t glyphid  = glyph_info[i].codepoint;
					//hb_position_t x_offset  = glyph_pos[i].x_offset;
					//hb_position_t y_offset  = glyph_pos[i].y_offset;
					hb_position_t x_advance = glyph_pos[i].x_advance;
					hb_position_t y_advance = glyph_pos[i].y_advance;

					PreparedGlyph glyph = .(currentFont, glyphid, .(penPosition, baseline), fontScale);//, x_advance / 64, y_advance / 64);

					preparedText.Glyphs.Add(glyph);

					penPosition += (x_advance / 64) * fontScale;
					baseline += (y_advance / 64) * fontScale;
				}

				preparedText.AdvanceX = Math.Max(preparedText.AdvanceX, penPosition);
			}

			void ResetPenPos()
			{
				preparedText.AdvanceX = Math.Max(preparedText.AdvanceX, penPosition);
				penPosition = 0;
			}

			for (char32 char in text.DecodedChars)
			{
				defer
				{
					currentIndex = @char.NextIndex;
				}

				switch(char)
				{
				case '\n':
					// Only flush after the first new line
					if (movedLines == 0)
						FlushShapeBuffer();

					// carriage return
					movedLines++;

					continue;
				case '\u{240}':
					FlushShapeBuffer();

					// carriage return
					ResetPenPos();

					continue;
				case '\u{2066}':
					// LEFT-TO-RIGHT ISOLATE
					FlushShapeBuffer();

					textDirectionStack.Add(.RightToLeft);

					continue;
				case '\u{2067}':
					// RIGHT-TO-LEFT ISOLATE
					FlushShapeBuffer();

					textDirectionStack.Add(.RightToLeft);

					continue;
				// TODO: FIRST STRONG ISOLATE (U+2068)
				case '\u{2069}':
					// POP DIRECTIONAL ISOLATE
					FlushShapeBuffer();

					if (textDirectionStack.Count > 1)
						textDirectionStack.PopBack();

					continue;
				}

				// Get the font that can draw the char. Use the given font if no fallback is found (will draw the "missing glyph").
				Font charFont = currentFont.GetDrawingFont(char) ?? font;

				if (charFont != currentFont)
				{
					FlushShapeBuffer();

					currentFont = charFont;
				}

				// move baseline if necessary
				if(movedLines != 0)
				{
					// move baseline
					baseline -= linespace * movedLines;

					// TODO: make carriage return optional?
					// return pen to start of line
					ResetPenPos();

					movedLines = 0;
				}

				//textBuffer.Append(char);
				if(textBuffer.Length == 0)
				{
					textBuffer.Ptr = text.Ptr + currentIndex;
				}
				textBuffer.Length += @char.NextIndex - currentIndex;
			}
			
			FlushShapeBuffer();
			
			preparedText.AdvanceY = baseline;

			return preparedText;
		}

		public static void DrawText(PreparedText text, float x, float y, Color fontColor = .White)
		{
			DrawText(text, Matrix.Translation(x, y, 0), fontColor);
		}

		public static void DrawText(PreparedText text, Matrix transform, Color fontColor = .White)
		{
			Debug.Profiler.ProfileRendererFunction!();

			text.AddRef();
			defer text.ReleaseRef();

			if (text.Glyphs.Count == 0)
				return;

			Renderer2D.Flush();

			// TODO: this is very not good!
			var lastEffect = Renderer2D.[Friend]s_currentEffect;
			Renderer2D.[Friend]s_currentEffect = _msdfEffect..AddRef();
			// TODO: oh no....
			// Copy viewProjection from current effect
			Matrix viewProjection = lastEffect.Variables["ViewProjection"].[Friend]GetData<Matrix>();
			_msdfEffect.Variables["ViewProjection"].SetData(viewProjection);
			
			// TODO: this doesn't really work with fallback fonts
			Vector2 unitRange = Vector2((float)text.Font._range) / Vector2(text.Font._atlas.Width, text.Font._atlas.Height);
			_msdfEffect.Variables["UnitRange"].SetData(unitRange);
			
			List<Texture2D> atlasses = scope .();

			for (PreparedGlyph glyph in text.Glyphs)
			{
				// Get glyph from Font
				var glyphDesc = glyph.Font.GetGlyph(glyph.GlyphId);

				// This never happens
				Debug.Assert(glyphDesc != null);

				// The glyph might belong to a fallback font
				var glyphFont = glyphDesc.Font;
				//float glyphFontScale = (float)glyph.Scale / glyphFont._fontSize;

				Texture2D atlas = glyphFont._atlas;

				// Add reference to atlas in case it is recreated during rendering
				if(!atlasses.Contains(atlas))
				{
					atlasses.Add(atlas..AddRef());
				}

				Vector2 atlasSize = .(atlas.Width, atlas.Height);

				float adjustToPenX = glyphDesc.AdjustToPen;
				//adjustToPenX *= glyphFontScale;
				adjustToPenX *= glyph.Scale;

				float adjustToBaseline = glyphDesc.AdjustToBaseLine;
				//adjustToBaseline *= glyphFontScale;
				adjustToBaseline *= glyph.Scale;

				// Rectangle on the screen
				Vector4 viewportRect = .(
					// TODO: merge adjustToPenX and adjustToBaseline into Position
					glyph.Position.X + adjustToPenX,
					glyph.Position.Y + adjustToBaseline,
					glyphDesc.Width * glyph.Scale,
					glyphDesc.Height * glyph.Scale);

				// Rectangle on the font atlas
				Vector4 texRect = .(glyphDesc.MapCoord.X, glyphDesc.MapCoord.Y, glyphDesc.Width, glyphDesc.Height);

				Color glyphColor = fontColor;//Color.White;// TODO: glyphDesc.IsBitmap ? bitmapColor : fontColor;

				texRect /= Vector4(atlasSize, atlasSize);

				// Show quads
				// Renderer2D.DrawQuad(Vector3(viewportRect.X + viewportRect.Z / 2, viewportRect.Y + viewportRect.W / 2, 1), .(viewportRect.Z, viewportRect.W), 0, .Red);

				Vector3 position = .(viewportRect.X + viewportRect.Z / 2, viewportRect.Y + viewportRect.W / 2, 0);

				Matrix glyphTransform = transform * Matrix.Translation(position) * Matrix.Scaling(viewportRect.Z, viewportRect.W, 1.0f);
				
				Renderer2D.DrawQuad(glyphTransform, atlas, glyphColor, texRect);
				//Renderer2D.DrawQuad(Vector2(viewportRect.X + viewportRect.Z / 2, viewportRect.Y + viewportRect.W / 2), .(viewportRect.Z, viewportRect.W), 0, atlas, glyphColor, texRect);

				// Show pen positions
				// Renderer2D.DrawQuad(Vector3(Vector2(x, y) + glyph.Position, -1), .(1), 0, .Green);
			}

			Renderer2D.Flush();

			// TODO: not good!
			// Change back effect
			_msdfEffect.ReleaseRef();
			Renderer2D.[Friend]s_currentEffect = lastEffect;
			
			// release all atlas textures
			for(int i < atlasses.Count)
			{
				atlasses[i].ReleaseRef();
			}
		}

		/** @brief Draws a given text using a specified font stack and renderer.
		 * @param renderer The 2D renderer that will be used to draw the text.
		 * @param font the Fontstack that will be used to draw the text.
		 * @param x The horizontal position of the text (i.e. distance between left side of viewport and the left side of the left-most character, well not really but close enough).
		 * @param y The vertical position of the text (i.e. distance between top side of viewport and the top side of the top-most character, well not really but close enough).
		 * @param fontSize The font size in pixels. Note: due to technical reasons the actual size might deviate from the specified size.
		 * @param fontColor The (default) color used for glyphs that don't have color (e.g. letters or emojies if the font doesn't use bitmaps for them).
		 * @param bitmapColor The (default) color used for glyphs that are bitmaps (e.g. emojies, if the font provies them as bitmap).
		 * @param lineGapOffset Can be used to manually increase or decrease the gap between lines.
		 */
		public static void DrawText(Font font, String text, float x, float y, float fontSize, Color fontColor = .White, Color bitmapColor = .White, float lineGapOffset = 0)
		{
			Debug.Profiler.ProfileRendererFunction!();

			if(text.IsWhiteSpace)
				return;
			
			Renderer2D.Flush();

			// TODO: this is very not good!
			var lastEffect = Renderer2D.[Friend]s_currentEffect;
			Renderer2D.[Friend]s_currentEffect = _msdfEffect..AddRef();
			// TODO: oh no....
			// Copy viewProjection from current effect
			Matrix viewProjection = lastEffect.Variables["ViewProjection"].[Friend]GetData<Matrix>();
			_msdfEffect.Variables["ViewProjection"].SetData(viewProjection);

			float scale = (float)fontSize / (float)font._fontSize;

			_msdfEffect.Variables["screenPixelRange"].SetData(scale * 4.0f);

			// TODO: this doesn't really work with fallback fonts
			Vector2 unitRange = Vector2((float)font._range) / Vector2(font._atlas.Width, font._atlas.Height);
			_msdfEffect.Variables["UnitRange"].SetData(unitRange);

			// Space between two baselines
			float linespace = ((float)font._linespace + lineGapOffset) * scale;
			
			// The line we are writing on
			float baseline = y;// + linespace;

			//renderer.Draw(null, x, baseline, 10000, 1, .Blue);

		    // Position of the next character on the line
			float penPosition = x;

			// how many lines we moved up or down (e.g. after a \n)
			int movedLines = 0;

			List<Texture2D> atlasses = scope .();
			// We render every char with a slightly greater depth, so that the chars don't cull each other.
			// In order to do that we increment an integer for each glyph and use it as the depth for the next one.
			// Whenn passing the depth to the renderer we treat the integer as the binary representation of a float.
			// Therefore every increment will increment the mantissa of the float and is therefore equivalent to the
			// smallest possible increase a float can represent.
			// Note: This might do funky stuff when objects are very close to each other. But realistically whe have to do
			// about 8 million (2^23) increments to reach a depth of 1 so I think it's safe enough.
			//float f = 1.0f;
			//int32 depthInt = *(int32*)&f;
			
			/*
			// Shape!!!!!!!!!!!!!!!!!!!

			// 1. Create a buffer and put your text in it:
			hb_buffer_t *buf;
			buf = hb_buffer_create();
			hb_buffer_add_utf8(buf, text.CStr(), -1, 0, -1);

			// 2. Set the script, language and direction of the buffer.
			hb_buffer_set_direction(buf, .HB_DIRECTION_LTR);
			hb_buffer_set_script(buf, .HB_SCRIPT_LATIN);
			hb_buffer_set_language(buf, hb_language_from_string("en".CStr(), -1));
			
			// 3. Get the face
			hb_font_t* hb_font = font._harfBuzzFont;
			
			// 4. Shape:
			hb_shape(hb_font, buf, null, 0);
			
			// 5. Get the glyph and position information.
			uint32 glyph_count = ?;
			hb_glyph_info_t* glyph_info    = hb_buffer_get_glyph_infos(buf, &glyph_count);
			hb_glyph_position_t* glyph_pos = hb_buffer_get_glyph_positions(buf, &glyph_count);

			for (uint32 i < glyph_count)
			{
				hb_codepoint_t glyphid  = glyph_info[i].codepoint;
				hb_position_t x_offset  = glyph_pos[i].x_offset;
				hb_position_t y_offset  = glyph_pos[i].y_offset;
				hb_position_t x_advance = glyph_pos[i].x_advance;
				hb_position_t y_advance = glyph_pos[i].y_advance;

				/*
				if(glyphid == (.)'\n')
				{
					movedLines++;
					continue;
				}
				
				// move baseline if necessary
				if(movedLines != 0)
				{
					// move baseline
					baseline -= linespace * movedLines;

					// TODO: make carriage return optional?
					// return pen to start of line
					penPosition = x;

					movedLines = 0;
				}
				*/

				// Get glyph from Font
				var glyphDesc = font.GetGlyph(glyphid);

				// This never happens
				Debug.Assert(glyphDesc != null);

				// The glyph might belong to a fallback font
				var glyphFont = glyphDesc.Font;
				float glyphFontScale = (float)fontSize / glyphFont._fontSize;

				Texture2D atlas = glyphFont._atlas;

				// Add reference to atlas in case it is recreated during rendering
				if(!atlasses.Contains(atlas))
				{
					atlasses.Add(atlas..AddRef());
				}

				Vector2 atlasSize = .(atlas.Width, atlas.Height);

				float adjustToPenX = glyphDesc.AdjustToPen;
				adjustToPenX *= glyphFontScale;

				float adjustToBaseline = glyphDesc.AdjustToBaseLine;
				adjustToBaseline *= glyphFontScale;

				// Rectangle on the screen
				Vector4 viewportRect = .(
					penPosition + adjustToPenX,
					baseline + adjustToBaseline,
					glyphDesc.Width * glyphFontScale,
					glyphDesc.Height * glyphFontScale);

				// Rectangle on the font atlas
				Vector4 texRect = .(glyphDesc.MapCoord.X, glyphDesc.MapCoord.Y, glyphDesc.Width, glyphDesc.Height);

				Color glyphColor = glyphDesc.IsBitmap ? bitmapColor : fontColor;

				texRect /= Vector4(atlasSize, atlasSize);

				// Show quads
				// Renderer2D.DrawQuad(Vector3(viewportRect.X + viewportRect.Z / 2, viewportRect.Y + viewportRect.W / 2, 1), .(viewportRect.Z, viewportRect.W), 0, .Red);

				Renderer2D.DrawQuad(Vector2(viewportRect.X + viewportRect.Z / 2, viewportRect.Y + viewportRect.W / 2), .(viewportRect.Z, viewportRect.W), 0, atlas, glyphColor, texRect);

				// Show pen positions
				// Renderer2D.DrawQuad(Vector3(penPosition, baseline, -1), .(1), 0, .Green);

			    penPosition += (x_advance / 64) * glyphFontScale;
			    baseline += (y_advance / 64) * glyphFontScale;
			}
			*/

			// enumerate through the unicode codepoints
			for(char32 char in text.DecodedChars)
			{
				if(char == '\n')
				{
					movedLines++;
					continue;
				}

				// move baseline if necessary
				if(movedLines != 0)
				{
					// move baseline
					baseline -= linespace * movedLines;

					// TODO: make carriage return optional?
					// return pen to start of line
					penPosition = x;

					movedLines = 0;
				}
				
				//renderer.Draw(null, penPosition, baseline - fontSize, 1, fontSize, .Lime);

				// Get glyph from Font
				var glyphDesc = font.GetGlyph(char);

				// This never happens
				Debug.Assert(glyphDesc != null);

				// The glyph might belong to a fallback font
				var glyphFont = glyphDesc.Font;
				float glyphFontScale = (float)fontSize / glyphFont._fontSize;

				Texture2D atlas = glyphFont._atlas;

				// Add reference to atlas in case it is recreated during rendering
				if(!atlasses.Contains(atlas))
				{
					atlasses.Add(atlas..AddRef());
				}

				Vector2 atlasSize = .(atlas.Width, atlas.Height);

				float adjustToPenX = glyphDesc.AdjustToPen;
				adjustToPenX *= glyphFontScale;

				float adjustToBaseline = glyphDesc.AdjustToBaseLine;
				adjustToBaseline *= glyphFontScale;
				
				// Rectangle on the screen
				Vector4 viewportRect = .(
					penPosition + adjustToPenX,
					baseline + adjustToBaseline,
					glyphDesc.Width * glyphFontScale,
					glyphDesc.Height * glyphFontScale);

				// Rectangle on the font atlas
				Vector4 texRect = .(glyphDesc.MapCoord.X, glyphDesc.MapCoord.Y, glyphDesc.Width, glyphDesc.Height);

				Color glyphColor = glyphDesc.IsBitmap ? bitmapColor : fontColor;

				texRect /= Vector4(atlasSize, atlasSize);

				Renderer2D.DrawQuad(Vector2(viewportRect.X + viewportRect.Z / 2, viewportRect.Y + viewportRect.W / 2), .(viewportRect.Z, viewportRect.W), 0, atlas, glyphColor, texRect);

				//renderer.Draw(atlas, viewportRect.X, viewportRect.Y, viewportRect.Z, viewportRect.W, glyphColor, *(float*)(&depthInt), texRect);

				penPosition += glyphDesc.Advance * glyphFontScale;

				// Increase depth for the next glyph
				//depthInt--;
			}

			Renderer2D.Flush();

			// TODO: not good!
			// Change back effect
			_msdfEffect.ReleaseRef();
			Renderer2D.[Friend]s_currentEffect = lastEffect;
			
			// release all atlas textures
			for(int i < atlasses.Count)
			{
				atlasses[i].ReleaseRef();
			}
		}
	}
}
