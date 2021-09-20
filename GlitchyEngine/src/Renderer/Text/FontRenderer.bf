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

		public static Effect _msdfEffect;

		static this()
		{
			FontRenderer.InitLibrary();
		}

		public static void Init(EffectLibrary effectLibrary)
		{
			if(effectLibrary.Exists("msdfShader"))
				_msdfEffect = effectLibrary.Get("msdfShader");
			else
				_msdfEffect = effectLibrary.Load("content\\Shaders\\msdfShader.hlsl");
		}

		public static void DeInit()
		{
			_msdfEffect?.ReleaseRef();
			_msdfEffect = null;
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
		public static void DrawText(Renderer2D renderer, Font font, String text, float x, float y, float fontSize, Color fontColor = .White, Color bitmapColor = .White, float lineGapOffset = 0)
		{
			if(text.IsWhiteSpace)
				return;
			
			renderer.End();
			var lastEffect = renderer.[Friend]_currentEffect;
			renderer.[Friend]_currentEffect = _msdfEffect..AddRef();
			
			float scale = (float)fontSize / (float)font._fontSize;
			
			_msdfEffect.Variables["screenPixelRange"].SetData(scale * 4.0f);

			// Space between two baselines
			float linespace = (((font._face.size.metrics.ascender - font._face.size.metrics.descender) / 64) + lineGapOffset) * scale;
			
			// The line we are writing on
			float baseline = y + linespace;

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
			float f = 1.0f;
			int32 depthInt = *(int32*)&f;

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
					baseline += linespace * movedLines;

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

				renderer.Draw(atlas, viewportRect.X, viewportRect.Y, viewportRect.Z, viewportRect.W, glyphColor, *(float*)(&depthInt), texRect);

				penPosition += glyphDesc.Advance * glyphFontScale;

				// Increase depth for the next glyph
				depthInt--;
			}

			renderer.End();

			_msdfEffect.ReleaseRef();
			renderer.[Friend]_currentEffect = lastEffect;
			
			// release all atlas textures
			for(int i < atlasses.Count)
			{
				atlasses[i].ReleaseRef();
			}
		}
	}
}
