using System.Runtime.CompilerServices;

namespace GlitchyEngine;

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

    //public static void LogDebug(string message)
    //{
    //    LogMessage_Impl(LogLevel.Info, message);
    //}

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
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern string LogMessage_Impl(LogLevel logLevel, string message);
}
