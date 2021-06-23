using System;
using FreeType;
using System.Diagnostics;
using GlitchyEngine.Math;
using System.Collections;

using internal GlitchyEngine.Renderer.Text;

namespace GlitchyEngine.Renderer.Text
{
	public class FontRenderer
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

		private GraphicsContext _context ~ _.ReleaseRef();

		public this(GraphicsContext context)
		{
			FontRenderer.InitLibrary();
			
			_context = context..AddRef();
		}

		public void DrawText(Renderer2D renderer, Font font, String text, float x, float y, Color fontColor = .White, Color bitmapColor = .White)
		{
			if(text.IsWhiteSpace)
				return;

			// Todo:
			float scale = 1.0f;

			// Space between two baselines
			float linespace = ((font._face.size.metrics.ascender - font._face.size.metrics.descender) >> 6);// + lineGap;
			
			// The line we are writing on
			float baseline = y + linespace;
            // Where we are writing the next glyph on the line
			float penPosition = x;

			int32 lastLine = 0;
			int32 line = 0;

			List<Texture2D> atlasses = scope .();

			//GlyphDescriptor missingGlyph = font.CharMap.GetValue('\0');
			String.UTF8Enumerator textEnumerator = String.UTF8Enumerator(text, 0, text.Length);
			for(char32 char in textEnumerator)
			{
				if(char == '\n')
				{
					line++;
					continue;
				}

				// number of lines that the cursor moved up or down
				int32 lineDiff = line - lastLine;
				if(lineDiff != 0)
				{
                	baseline += linespace * lineDiff;

					// TODO: make carriage return optional?
                	penPosition = x;

					lastLine = line;
				}

				// Get glyph from Font
				var glyphDesc = font.GetGlyph(char);

				// This never happens
				if(glyphDesc == null)
				{
					Debug.Break();
					continue;
				}

				// Rectangle on the screen
				Vector4 viewportRect = .(penPosition + (glyphDesc.Metrics.horiBearingX / 64) * scale, baseline - (glyphDesc.Metrics.horiBearingY / 64) * scale, glyphDesc.SizeX * scale, glyphDesc.SizeY * scale);
				// Rectangle on the font atlas
				Vector4 texRect = .(glyphDesc.MapCoord.X, glyphDesc.MapCoord.Y, glyphDesc.SizeX, glyphDesc.SizeY);

				Color glyphColor = glyphDesc.IsBitmap ? bitmapColor : fontColor;

				/*
				if(QueueQuad!(viewportRect, texRect, glyphDesc.MapZ, glyphColor))
				{
					DrawQueue(context);
				}
				*/

				Texture2D atlas = glyphDesc.Font.[Friend]_atlas;

				if(!atlasses.Contains(atlas))
				{
					atlasses.Add(atlas..AddRef());
				}

				Vector2 atlasSize = .(atlas.Width, atlas.Height);

				texRect /= Vector4(atlasSize, atlasSize);

				renderer.Draw(atlas, viewportRect.X, viewportRect.Y, viewportRect.Z, viewportRect.W, glyphColor, 0.0f, texRect);

				penPosition += (glyphDesc.Metrics.horiAdvance / 64) * scale;
			}

			renderer.End();

			for(int i < atlasses.Count)
			{
				atlasses[i].ReleaseRef();
			}
		}
	}
}
