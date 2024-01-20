using System;

namespace GlitchLog;

public abstract class Logger
{
	protected LogLevel _logLevel;
	
	public LogLevel Level
	{
		get => _logLevel;
		set => _logLevel = value;
	}

	public abstract String Name {get; set;}

	public abstract void Trace(StringView format, params Object[] args);
	public abstract void Info(StringView format, params Object[] args);
	public abstract void Warning(StringView format, params Object[] args);
	public abstract void Error(StringView format, params Object[] args);
	public abstract void Critical(StringView format, params Object[] args);

	public abstract void Assert(bool condition, String error = Compiler.CallerExpression[0], String filePath = Compiler.CallerFilePath, int line = Compiler.CallerLineNum);

#if !DEBUG
	[SkipCall]
#endif
	public abstract void AssertDebug(bool condition, String error = Compiler.CallerExpression[0], String filePath = Compiler.CallerFilePath, int line = Compiler.CallerLineNum);

	public abstract void Log(LogLevel level, StringView format, params Object[] args);
}
