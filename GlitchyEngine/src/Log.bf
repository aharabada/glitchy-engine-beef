using System;
using GlitchLog;

namespace GlitchyEngine
{
	public class Log
	{
		static Logger _engineLogger ~ delete _;
		static Logger _clientLogger ~ delete _;

		[Inline]
		public static Logger EngineLogger => _engineLogger;
		[Inline]
		public static Logger ClientLogger => _clientLogger;

		static this()
		{
			GlitchLog.Format = "[{t:HH:mm:ss.fff}] ({n})|{l}: {m}";

			_engineLogger = new DebugLogger();
			_engineLogger.Name = "ENGINE";
			_engineLogger.Level = .Trace;

			_clientLogger = new DebugLogger();
			_clientLogger.Name = "APP";
			_clientLogger.Level = .Trace;
		}
	}
}
