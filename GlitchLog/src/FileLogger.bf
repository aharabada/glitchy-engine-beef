using System;
using System.IO;
using System.Text;

namespace GlitchLog
{
	public class FileLogger : ILogger
	{
		StreamWriter _sw ~ delete _;

		[AllowAppend]
		public this(String fileName)
		{
			var sw = append StreamWriter();
			_sw = sw;
			_sw.Create(fileName);
		}

		public void Trace(StringView format, params Object[] args)
		{
			_sw.Write("TRACE: ");
			_sw.WriteLine(format, params args);
		}

		public void Info(StringView format, params Object[] args)
		{
			_sw.Write("INFO: ");
			_sw.WriteLine(format, params args);
		}

		public void Warning(StringView format, params Object[] args)
		{
			_sw.Write("WARNING: ");
			_sw.WriteLine(format, params args);
		}

		public void Error(StringView format, params Object[] args)
		{
			_sw.Write("ERROR: ");
			_sw.WriteLine(format, params args);
		}
	}
}
