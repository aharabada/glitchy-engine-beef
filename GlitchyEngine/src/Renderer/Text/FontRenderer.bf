using System;
using FreeType;
using System.Diagnostics;
using GlitchyEngine.Math;
using System.Collections;

using internal GlitchyEngine.Renderer.Text;

namespace GlitchyEngine.Renderer.Text
{
	public static class FontRenderer
	{
		internal static FT_Library Library ~ FreeType.Done_FreeType(_);

		internal static void InitLibrary()
		{
			if(Library == null)
			{
				var res = FreeType.Init_FreeType(&Library);
				Log.EngineLogger.Assert(res.Success, scope $"Init_FreeType failed({(int)res}): {res}");
			}
		}

		static this()
		{
			FontRenderer.InitLibrary();
		}

		/** @brief Draws a given text using a specified font stack and renderer.
		 * @param renderer The 2D renderer that will be used to draw the text.
		 * @param font the Fontstack that will be used to draw the text.
		 * @param x The horizontal position of the text (i.e. distance between left side of viewport and the left side of the left-most character, well not really but close enough).
		 * @param y The vertical position of the text (i.e. distance between top side of viewport and the top side of the top-most character, well not really but close enough).
		 * @param fontColor The (default) color used for glyphs that don't have color (e.g. letters or emojies if the font doesn't use bitmaps for them).
		 * @param bitmapColor The (default) color used for glyphs that are bitmaps (e.g. emojies, if the font provies them as bitmap).
		 * @param fontSize The font size in pixels. If set to 0 the default size of the font will be used. Note: due to technical reasons the actual size might deviate from the specified size.
		 * @param lineGapOffset Can be used to manually increase or decrease the gap between lines.
		 */
		public static void DrawText(Renderer2D renderer, Font font, String text, float x, float y, Color fontColor = .White, Color bitmapColor = .White, float fontSize = 0, float lineGapOffset = 0)
		{
			if(text.IsWhiteSpace)
				return;

			float scale = 1.0f;

			if(fontSize != 0)
			{
				scale = (float)fontSize / (float)font._fontSize;
			}

			// Space between two baselines
			float linespace = (((font._face.size.metrics.ascender - font._face.size.metrics.descender) / 64) + lineGapOffset) * scale;
			
			// The line we are writing on
			float baseline = y + linespace;
		    // Position of the next character on the line
			float penPosition = x;

			// how many lines we moved up or down (e.g. after a \n)
			int movedLines = 0;

			List<Texture2D> atlasses = scope .();

			// freetype identifies glyphs using utf32 (which makes sense), so we enumerate the text as char32
			for(char32 char in String.UTF8Enumerator(text, 0, text.Length))
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
					baseline += linespace * movedLines;

					// TODO: make carriage return optional?
					// return pen to start of line
					penPosition = x;

					movedLines = 0;
				}

				// Get glyph from Font
				var glyphDesc = font.GetGlyph(char);

				// This never happens
				Debug.Assert(glyphDesc != null);

				Texture2D atlas = glyphDesc.Font._atlas;

				// Add reference to atlas in case it is recreated during rendering
				if(!atlasses.Contains(atlas))
				{
					atlasses.Add(atlas..AddRef());
				}

				Vector2 atlasSize = .(atlas.Width, atlas.Height);

				// Rectangle on the screen
				Vector4 viewportRect = .(
					penPosition + (glyphDesc.Metrics.horiBearingX / 64) * scale,
					baseline - (glyphDesc.Metrics.horiBearingY / 64) * scale,
					glyphDesc.SizeX * scale,
					glyphDesc.SizeY * scale);

				// Rectangle on the font atlas
				Vector4 texRect = .(glyphDesc.MapCoord.X, glyphDesc.MapCoord.Y, glyphDesc.SizeX, glyphDesc.SizeY);

				Color glyphColor = glyphDesc.IsBitmap ? bitmapColor : fontColor;

				texRect /= Vector4(atlasSize, atlasSize);

				renderer.Draw(atlas, viewportRect.X, viewportRect.Y, viewportRect.Z, viewportRect.W, glyphColor, 0.0f, texRect);

				penPosition += (glyphDesc.Metrics.horiAdvance / 64) * scale;
			}

			renderer.End();
			
			// release all atlas textures
			for(int i < atlasses.Count)
			{
				atlasses[i].ReleaseRef();
			}
		}
	}
}
