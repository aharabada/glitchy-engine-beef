using System;
using FreeType;
using System.Diagnostics;
using GlitchyEngine.Math;
using System.Collections;
using GlitchyEngine.Core;
using GlitchyEngine.Content;
using System.Text;
using GlitchyEngine.World.Components;
using static FreeType.HarfBuzz;

using internal GlitchyEngine.Renderer.Text;
using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer.Text
{
	public static class FontRenderer
	{
		internal static FT_Library s_Library;

		public static AssetHandle<Effect> _msdfEffect;
		public static Material _msdfMaterial ~ _?.ReleaseRef();

		internal static bool s_isInitialized;

		internal static void Init()
		{
			Debug.Profiler.ProfileFunction!();

			if(s_isInitialized)
				return;

			InitFreetype();

			// TODO: We might get away with a non blocking load here, but not for now!
			_msdfEffect = Content.LoadAsset("Resources/Shaders/msdfShader.fx", null, true);
			_msdfMaterial = new Material(_msdfEffect);

			s_isInitialized = true;
		}

		internal static void Deinit()
		{
			Debug.Profiler.ProfileFunction!();

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

		public class PreparedText : RefCounter
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

			/// Optimizes rendering of the text by sorting the glyphs
			public void Optimize()
			{
				// Sort by texture -> render all glyphs with same font at once
				Glyphs.Sort((lhs, rhs) => (int)Internal.UnsafeCastToPtr(lhs.Font._atlas) - (int)Internal.UnsafeCastToPtr(rhs.Font._atlas));
			}

			public void Clear()
			{
				Glyphs.Clear();
			}
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
			public float2 Position;
			public float Scale;
			//public float AdvanceX;
			//public float AdvanceY;

			public this(Font font, uint32 glyphId, float2 position, float scale)//, float advanceX, float advanceY)
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

		public enum TextCase
		{
			case RetainCase;
			case UpperCase;
			case LowerCase;
			case InvertCase;
		}

		public enum HorizontalTextAlignment
		{
			case Left;
			case Right;
			case Center;
		}

		class StyleStack<T>
		{
			private append List<T> _stack = .();

			public this(T bottomValue)
			{
				_stack.Add(bottomValue);
			}

			public void Push(T value)
			{
				_stack.Add(value);
			}

			public T CurrentValue()
			{
				return _stack.Back;
			}

			public T Pop()
			{
				if (_stack.Count == 1)
					return _stack[0];

				return _stack.PopBack();
			}

			/// If popValue is true, the given value will not be pushed and the current top of the stack will be poped.
			/// If popValaue is false, the given value will be pushed and returned.
			public T PushButPopIfTrue(T value, bool popValue)
			{
				if (popValue)
				{
					return Pop();
				}
				else
				{
					Push(value);
					return value;
				}	
			}
		}	

		public static void PrepareText(TextRendererComponent* textRenderer, Font font)
		{
			Debug.Profiler.ProfileRendererFunction!();

			if (textRenderer.Text.IsWhiteSpace)
				return;
			
			if (textRenderer.PreparedText == null)
			{
				textRenderer.PreparedText = new FontRenderer.PreparedText(font);
			}
			else
			{
				textRenderer.PreparedText.AddRef();
			}

			PreparedText preparedText = textRenderer.PreparedText;
			preparedText.Clear();

			// The line we are writing on
			float baseline = 0;
			
			// Position of the next character on the line
			float penPosition = 0;

			List<char32> chars = new:ScopedAlloc! .(textRenderer.Text.Length);
			int runStart = 0;

			hb_buffer_t* buf = hb_buffer_create();

			// Stack to keep track of the text direction.
			StyleStack<TextDirection> textDirectionStack = scope .(.LeftToRight);

			StyleStack<TextCase> textCaseStack = scope .(.RetainCase);
			
			StyleStack<bool> richTextStack = scope .(true);

			StyleStack<ColorRGBA> fontColorStack = scope .(textRenderer.Color);

			StyleStack<float> fontSizeStack = scope .(textRenderer.FontSize);

			StyleStack<Font> fontStack = scope .(font);

			StyleStack<float> lineSpaceStack = scope .(1.0f);

			float scale()
			{
				return fontSizeStack.CurrentValue() / fontStack.CurrentValue()._fontSize;
			}

			float linespace()
			{
				return (float)fontStack.CurrentValue()._linespace * lineSpaceStack.CurrentValue() * scale();
			}

			List<int> lineStartIndices = scope .();
			lineStartIndices.Add(0);
			List<float> lineWidths = scope .();

			int movedLines = 0;

			Font currentFont = font;

			int currentIndex = 0;

			void FlushShapeBuffer()
			{
				Debug.Profiler.ProfileRendererFunction!();

				float fontScale = scale();

				hb_buffer_clear_contents(buf);

				hb_buffer_add_utf32(buf, chars.Ptr, (.)chars.Count, (.)runStart, (.)(chars.Count - runStart));

				runStart = chars.Count;

				// Set the script, language and direction of the buffer.
				// TODO: change direction, script, etc.

				TextDirection direction = textDirectionStack.CurrentValue();

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

					// TODO Store color in glyph
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

			bool escapeNextChar = false;

			mainEnumerator: for (char32 char in textRenderer.Text.DecodedChars)
			{
				defer
				{
					currentIndex = @char.NextIndex;
				}

				void DoLineBreak()
				{
					//chars.Add('\n');
					// Only flush after the first new line
					if (movedLines == 0)
						FlushShapeBuffer();

					// carriage return
					movedLines++;
				}

				switch(char)
				{
				case '\n':
					DoLineBreak();
					continue;
				case '\u{240}':
					FlushShapeBuffer();

					// carriage return
					ResetPenPos();

					continue;
				case '\u{2066}':
					// LEFT-TO-RIGHT ISOLATE
					FlushShapeBuffer();

					textDirectionStack.Push(.RightToLeft);

					continue;
				case '\u{2067}':
					// RIGHT-TO-LEFT ISOLATE
					FlushShapeBuffer();

					textDirectionStack.Push(.RightToLeft);

					continue;
				// TODO: FIRST STRONG ISOLATE (U+2068)
				case '\u{2069}':
					// POP DIRECTIONAL ISOLATE
					FlushShapeBuffer();

					textDirectionStack.Pop();

					continue;
				case '\\':
					if (escapeNextChar)
						break;
					else
					{
						escapeNextChar = true;
						continue;
					}
				case '<':
					if (escapeNextChar)
						break;

					// Copy the char enumerator to make a lookahead
					String.UTF8Enumerator tagEnumerator = @char;

					String tagText = scope .();

					int endIndex = -1;

					for (char32 tagChar in tagEnumerator)
					{
						if (tagChar == '>')
						{
							endIndex = tagEnumerator.NextIndex;
							break;
						}
						else
						{
							UTF32.Decode(Span<char32>(&tagChar, 1), tagText);
						}
					}

					// It seems that it's just an unescaped <
					if (endIndex == -1)
						break; // TODO: Probably warn or something

					bool isEndTag = tagText.StartsWith('/');

					if (isEndTag)
						tagText.Remove(0);

					tagText.ToLower();

					if (tagText == "rt" || tagText == "richtext")
					{
						richTextStack.PushButPopIfTrue(true, isEndTag);
						
						// Skip the tag in the main enumerator
						@char.NextIndex = endIndex;
						continue;
					}

					if (tagText == "pt" || tagText == "plaintext")
					{
						richTextStack.PushButPopIfTrue(false, isEndTag);
						
						// Skip the tag in the main enumerator
						@char.NextIndex = endIndex;
						continue;
					}

					// Only process the other tags if we currently use rich text processing
					if (!richTextStack.CurrentValue())
						break;

					switch(tagText)
					{
					case "b", "bold":
						// bold
					case "br", "linebreak":
						DoLineBreak();
					case "u", "underline":
						// underlined
					case "i", "italic":
						// italic
					case "small":
					case "sub", "subscript":
					case "sup", "superscript":
					case "s", "strikethrough":

						// Text case control
					case "lc", "lowercase":
						textCaseStack.PushButPopIfTrue(.LowerCase, isEndTag);
					case "uc", "uppercase":
						if (isEndTag)
						textCaseStack.PushButPopIfTrue(.UpperCase, isEndTag);
					case "rc", "retaincase":
						textCaseStack.PushButPopIfTrue(.RetainCase, isEndTag);
					case "ic", "invertcase":
						textCaseStack.PushButPopIfTrue(.InvertCase, isEndTag);
					}

					// Skip the tag in the main enumerator
					@char.NextIndex = endIndex;
					continue;
				}

				escapeNextChar = false;

				switch (textCaseStack.CurrentValue())
				{
				case .RetainCase:
					// Nothing to do
				case .LowerCase:
					char = char.ToLower;
				case .UpperCase:
					char = char.ToUpper;
				case .InvertCase:
					if (char.IsUpper)
						char = char.ToLower;
					else if (char.IsLower)
						char = char.ToUpper;
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
					baseline -= linespace() * movedLines;

					lineWidths.Add(penPosition);

					// TODO: make carriage return optional?
					// return pen to start of line
					ResetPenPos();

					movedLines = 0;

					lineStartIndices.Add(preparedText.Glyphs.Count);
				}

				chars.Add(char);
			}
			
			FlushShapeBuffer();

			lineWidths.Add(penPosition);

			for (int i = 0; i < lineStartIndices.Count; i++)
			{
				int currentLineStart = lineStartIndices[i];
				int nextLineStart = i < (lineStartIndices.Count - 1) ? lineStartIndices[i + 1] : preparedText.Glyphs.Count;

				float offset = 0.0f;

				if (textRenderer.HorizontalAlignment == .Center)
					offset = lineWidths[i] / 2.0f;
				else if (textRenderer.HorizontalAlignment == .Right)
					offset = lineWidths[i];

				for (int glyphIndex = currentLineStart; glyphIndex < nextLineStart; glyphIndex++)
				{
					preparedText.Glyphs[glyphIndex].Position.X -= offset;
				}
			}

			preparedText.AdvanceY = baseline;

			preparedText.Optimize();

			textRenderer.PreparedText.ReleaseRef();
			textRenderer.NeedsRebuild = false;
		}

		public static void DrawText(PreparedText text, Matrix transform, ColorRGBA fontColor = .White, uint32 entityId = uint32.MaxValue)
		{
			Debug.Profiler.ProfileRendererFunction!();

			text.AddRef();
			defer text.ReleaseRef();

			if (text.Glyphs.Count == 0)
				return;

			// TODO: this doesn't really work with fallback fonts unless we use the same settings for all fonts
			float2 unitRange = ((float)text.Font._range) / float2(text.Font._atlas.Width, text.Font._atlas.Height);
			_msdfMaterial.SetVariable("UnitRange", unitRange);
			
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

				float2 atlasSize = .(atlas.Width, atlas.Height);

				float adjustToPenX = glyphDesc.AdjustToPen;
				adjustToPenX *= glyph.Scale;

				float adjustToBaseline = glyphDesc.AdjustToBaseLine;
				adjustToBaseline *= glyph.Scale;

				// Rectangle on the screen
				float4 viewportRect = .(
					// TODO: merge adjustToPenX and adjustToBaseline into Position
					glyph.Position.X + adjustToPenX,
					glyph.Position.Y + adjustToBaseline,
					glyphDesc.Width * glyph.Scale,
					glyphDesc.Height * glyph.Scale);

				// Rectangle on the font atlas
				float4 texRect = .(glyphDesc.MapCoord.X, glyphDesc.MapCoord.Y, glyphDesc.Width, glyphDesc.Height);

				ColorRGBA glyphColor = fontColor;//Color.White;// TODO: glyphDesc.IsBitmap ? bitmapColor : fontColor;

				texRect /= float4(atlasSize, atlasSize);

				float3 position = .(viewportRect.X + viewportRect.Z / 2, viewportRect.Y + viewportRect.W / 2, 0);

				Matrix glyphTransform = transform * Matrix.Translation(position) * Matrix.Scaling(viewportRect.Z, viewportRect.W, 1.0f);
				
				Renderer2D.DrawQuad(glyphTransform, atlas, material: _msdfMaterial, color: glyphColor, uvTransform: texRect, entityId: entityId);
			}

			// TODO: Get rid of the flush.
			// We need to flush, because currently Renderer2D doesn't increase the counter of passed textures.
			// Once it does that, we can
			// 1. Stop manually holding the references in this method
			// 2. Stop forcing a flush (which could make having multiple text instances way more efficient)
			Renderer2D.Flush();

			// release all atlas textures
			for(int i < atlasses.Count)
			{
				atlasses[i].ReleaseRef();
			}
		}
	}
}
