using System;

namespace GlitchLog
{
	public interface ILogger
	{
		void Trace(StringView format, params Object[] args);
		void Info(StringView format, params Object[] args);
		void Warning(StringView format, params Object[] args);
		void Error(StringView format, params Object[] args);
	}
}
