using System;

namespace GlitchyEngine.Benchmark;

static class Formatter
{
	public static CenterFormatter<T> Center<T>(T value, int width, bool leftAlignWhenUneven = true)
	{
		return CenterFormatter<T>(value, width, leftAlignWhenUneven);
	}
	
	public struct CenterFormatter<T> : IFormattable
	{
		private T _value;
		private int _width;
		private bool _leftAlignWhenUneven;

		public this(T value, int width, bool leftAlignWhenUneven = true)
		{
			_value = value;
			_width = width;
			_leftAlignWhenUneven = leftAlignWhenUneven;
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

			int widthAfterLeftPad = _width - missingSpaceCount / 2;
			// If the number of spaces is uneven and we want to left align (have more space right) we need to pad one less on the left
			if (_leftAlignWhenUneven && missingSpaceCount % 2 == 1)
				widthAfterLeftPad -= 1;
		 
			buffer..PadLeft(widthAfterLeftPad);
			outString..Append(buffer).PadRight(_width, ' ');
		}
	}
}
