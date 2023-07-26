using System;
using GlitchLog;

namespace GlitchyEngine
{
	public class Log
	{
		static Logger _engineLogger ~ delete _;
		static Logger _clientLogger ~ delete _;

		public static Logger EngineLogger
		{
			[Inline]
			get => _engineLogger;
			set
			{
				if (_engineLogger == value)
					return;

				delete _engineLogger;
				_engineLogger = value;
			}
		}
		
		public static Logger ClientLogger
		{
			[Inline]
			get => _clientLogger;
			set
			{
				if (_clientLogger == value)
					return;

				delete _clientLogger;
				_clientLogger = value;
			}
		}

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
