using System.Runtime.CompilerServices;

namespace GlitchyEngine;

/// <summary>
/// Provides methods to log messages to the Engine Console.
/// </summary>
public class Log
{
    public enum LogLevel
    {
        Trace = 0,
        Debug,
        Info,
        Warning,
        Error,
        Critical,
        Off
    }
    
    public static void Trace(string message)
    {
        LogMessage_Impl(LogLevel.Trace, message);
    }

    public static void Info(string message)
    {
        LogMessage_Impl(LogLevel.Info, message);
    }

    public static void Warning(string message)
    {
        LogMessage_Impl(LogLevel.Warning, message);
    }

    public static void Error(string message)
    {
        LogMessage_Impl(LogLevel.Error, message);
    }

    public static void Critical(string message)
    {
        LogMessage_Impl(LogLevel.Critical, message);
    }
    
    public static void Trace(object obj)
    {
        LogMessage_Impl(LogLevel.Trace, obj.ToString());
    }
    public static void Info(object obj)
    {
        LogMessage_Impl(LogLevel.Info, obj.ToString());
    }
    public static void Warning(object obj)
    {
        LogMessage_Impl(LogLevel.Warning, obj.ToString());
    }
    public static void Error(object obj)
    {
        LogMessage_Impl(LogLevel.Error, obj.ToString());
    }

    public static void Critical(object obj)
    {
        LogMessage_Impl(LogLevel.Critical, obj.ToString());
    }

    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern string LogMessage_Impl(LogLevel logLevel, string message);
}
