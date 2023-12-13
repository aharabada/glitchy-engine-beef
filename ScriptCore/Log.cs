using System.Runtime.CompilerServices;

namespace GlitchyEngine;

/// <summary>
/// Provides methods to log messages to the Engine Console.
/// </summary>
public class Log
{
    /// <summary>
    /// The severity of the log message.
    /// </summary>
    private enum LogLevel
    {
        Trace = 0,
        Debug,
        Info,
        Warning,
        Error,
        Critical,
        Off
    }
    
    /// <summary>
    /// Logs a trace message.
    /// </summary>
    /// <param name="message">The message to log.</param>
    public static void Trace(string message)
    {
        LogMessage_Impl(LogLevel.Trace, message);
    }
    
    /// <summary>
    /// Logs an info message.
    /// </summary>
    /// <param name="message">The message to log.</param>
    public static void Info(string message)
    {
        LogMessage_Impl(LogLevel.Info, message);
    }
    
    /// <summary>
    /// Logs a warning message.
    /// </summary>
    /// <param name="message">The message to log.</param>
    public static void Warning(string message)
    {
        LogMessage_Impl(LogLevel.Warning, message);
    }
    
    /// <summary>
    /// Logs an error message.
    /// </summary>
    /// <param name="message">The message to log.</param>
    public static void Error(string message)
    {
        LogMessage_Impl(LogLevel.Error, message);
    }
    
    /// <summary>
    /// Logs a critical error message.
    /// </summary>
    /// <param name="message">The message to log.</param>
    public static void Critical(string message)
    {
        LogMessage_Impl(LogLevel.Critical, message);
    }
    
    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as a trace message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    public static void Trace(object obj)
    {
        LogMessage_Impl(LogLevel.Trace, obj.ToString());
    }
    
    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as an info message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    public static void Info(object obj)
    {
        LogMessage_Impl(LogLevel.Info, obj.ToString());
    }

    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as a warning message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    public static void Warning(object obj)
    {
        LogMessage_Impl(LogLevel.Warning, obj.ToString());
    }

    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as an error message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    public static void Error(object obj)
    {
        LogMessage_Impl(LogLevel.Error, obj.ToString());
    }
    
    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as a critical error message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    public static void Critical(object obj)
    {
        LogMessage_Impl(LogLevel.Critical, obj.ToString());
    }

    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern string LogMessage_Impl(LogLevel logLevel, string message);
}
