using System;

namespace GlitchyEngine.Benchmark;

static class Formatter
{
	public static AlignFormatter<T> LeftAlign<T>(T value, int width)
	{
		return AlignFormatter<T>(value, width, .Left);
	}

	public static AlignFormatter<T> RightAlign<T>(T value, int width)
	{
		return AlignFormatter<T>(value, width, .Right);
	}

	public static AlignFormatter<T> Center<T>(T value, int width, bool leftAlignWhenUneven = true)
	{
		return AlignFormatter<T>(value, width, .Center(leftAlignWhenUneven));
	}

	public enum Align
	{
		case Left;
		case Center(bool LeftAlignWhenUneven);
		case Right;
	}

	public struct AlignFormatter<T> : IFormattable
	{
		private T _value;
		private int _width;
		private Align _align;

		public this(T value, int width, Align align)
		{
			_value = value;
			_width = width;
			_align = align;
		}

		public void ToString(String outString, String format, IFormatProvider formatProvider)
		{
			String buffer = scope String(128);
			IFormattable formattableArg = _value as IFormattable;
			if (formattableArg != null)
				formattableArg.ToString(buffer, format, formatProvider);
			else if (_value != null)
				_value.ToString(buffer);
			else
				buffer.Append("null");
			
			int missingSpaceCount = _width - buffer.Length;

			switch (_align)
			{
			case .Left:
				buffer.PadRight(_width, ' ');
			case .Center(bool leftAlignWhenUneven):
				int widthAfterLeftPad = _width - missingSpaceCount / 2;
				// If the number of spaces is uneven and we want to left align (have more space right) we need to pad one less on the left
				if (leftAlignWhenUneven && missingSpaceCount % 2 == 1)
					widthAfterLeftPad -= 1;
				buffer..PadLeft(widthAfterLeftPad).PadRight(_width, ' ');
			case .Right:
				buffer.PadLeft(_width, ' ');
			}

			outString.Append(buffer);
		}

		public override void ToString(String strBuffer)
		{
			ToString(strBuffer, null, null);
		}
	}
}
