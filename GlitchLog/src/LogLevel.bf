using System;

namespace GlitchLog
{
	/**
	 * Defines the severity level of a log message.
	 * @remarks also used to determine which levels will be logged.
	 */
	public enum LogLevel
	{
		case Trace = 0;
		case Debug;
		case Info;
		case Warning;
		case Error;
		case Critical;
		case Off;

		public static readonly StringView[?] UpperStringViews = .("TRACE", "DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL", "OFF");

		[Inline]
		public StringView UpperString => UpperStringViews[this.Underlying];
	}
}
