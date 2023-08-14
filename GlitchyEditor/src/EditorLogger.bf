using GlitchLog;
using System;
using System.Diagnostics;
using GlitchyEngine.Scripting;

namespace GlitchyEditor;

public class EditorLogger : Logger
{
	// {l} = log level (first parameter)
	// {t} = current date time (second parameter)
	// {n} = logger name (third parameter)
	// {m} = message

	private String _name;

	public override String Name
	{
		get => _name;
		set => _name = value;
	}

	public bool IsEngineLogger {get; set;}

	public this()
	{
		//Debug.Assert(Debug.IsDebuggerPresent, "The DebugLogger requires a debugger to be present.");
	}
	
#if GL_NOLOG || GL_LOG_NOTRACE
	[SkipCall]
#endif
	[Inline]
	public override void Trace(StringView format, params Object[] args)
	{
		InternalLog(.Trace, format, params args);
	}
	
#if GL_NOLOG || GL_LOG_NOINFO
	[SkipCall]
#endif
	[Inline]
	public override void Info(StringView format, params Object[] args)
	{
		InternalLog(.Info, format, params args);
	}
	
#if GL_NOLOG || GL_LOG_NOWARNING
	[SkipCall]
#endif
	[Inline]
	public override void Warning(StringView format, params Object[] args)
	{
		InternalLog(.Warning, format, params args);
	}

#if GL_NOLOG || GL_LOG_NOERROR
	[SkipCall]
#endif
	[Inline]
	public override void Error(StringView format, params Object[] args)
	{
		InternalLog(.Error, format, params args);
	}

#if GL_NOLOG || GL_LOG_NOCRITICAL
	[SkipCall]
#endif
	[Inline]
	public override void Critical(StringView format, params Object[] args)
	{
		InternalLog(.Critical, format, params args);
	}
	
#if GL_NOLOG
	[SkipCall]
#endif
	[Inline]
	public override void Log(LogLevel level, StringView format, params Object[] args)
	{
		InternalLog(level, format, params args);
	}

	public override void Assert(bool condition, String error = Compiler.CallerExpression[0], String filePath = Compiler.CallerFilePath, int line = Compiler.CallerLineNum)
	{
		if (!condition)
		{
			String failStr = scope .()..AppendF("Assert failed: {} at line {} in {}", error, line, filePath);
			InternalLog(.Critical, failStr);
			Internal.FatalError(failStr, 1);
		}
	}

	public override void AssertDebug(bool condition, String error = Compiler.CallerExpression[0], String filePath = Compiler.CallerFilePath, int line = Compiler.CallerLineNum)
	{
		if (!condition)
		{
			String failStr = scope .()..AppendF("Assert failed: {} at line {} in {}", error, line, filePath);
			InternalLog(.Critical, failStr);
			Internal.FatalError(failStr, 1);
		}
	}

	private void InternalLog(LogLevel level, StringView format, params Object[] args)
	{
		if(_logLevel > level)
			return;
		
		DateTime timestamp = DateTime.Now;

		String message = scope String(4096);
		message.AppendF(format, params args);

		Debug.Write($"[{timestamp:HH:mm:ss.fff}] ({_name})|{level.UpperString}: {message}\n");

		if (Editor.Instance?.LogWindow == null)
			return;

		if (args.Count > 0 && (var ex = args[^1] as MonoExceptionHelper))
		{
			Editor.Instance.LogWindow.LogException(timestamp, ex);
		}
		else
		{
			Editor.Instance.LogWindow.Log(timestamp, level, message, new .() {IsEngineMessage = IsEngineLogger});
		}
	}
}
