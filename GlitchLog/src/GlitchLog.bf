using System;
using System.Text;
using System.Diagnostics;

namespace GlitchLog
{
	public static class GlitchLog
	{
		private static String _format;
		internal static String _preparedFormat ~ delete _;
		internal static StringView _preMsgFormat;
		internal static StringView _postMsgFormat;

		public static String Format
		{
			get => _format;
			set
			{
				_format = value;

				PrepareFormat();
			}
		}

		static void PrepareFormat()
		{
			delete _preparedFormat;

			// Length = 0 -> no format -> only print msg
			if(_format.Length == 0)
			{
				_preMsgFormat.Ptr = null;
				_postMsgFormat.Ptr = null;
			}

			_preparedFormat = new .(_format);

			// Todo: this is utter garbage
			_preparedFormat.Replace("{l", "{0");
			_preparedFormat.Replace("{t", "{1");
			_preparedFormat.Replace("{n", "{2");

			int index = _preparedFormat.IndexOf("{m}");

			// {m} not in format-string -> format is pre msg
			if(index == -1)
			{
				_preMsgFormat = _preparedFormat;
				_postMsgFormat.Ptr = null;
			}
			else
			{
				if(index == 0)
					_preMsgFormat.Ptr = null;
				else
					_preMsgFormat = .(_preparedFormat, 0, index);
				
				if(index == _preparedFormat.Length - 3)
					_postMsgFormat.Ptr = null;
				else
					_postMsgFormat = .(_preparedFormat, index + 3, _preparedFormat.Length - index - 3);
			}
		}
	}
}
