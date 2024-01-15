using System;

namespace GlitchyEngine;

/// <summary>
/// Provides methods to log messages to the Engine Console.
/// </summary>
public class Log
{
    /// <summary>
    /// The severity of the log message.
    /// </summary>
    internal enum LogLevel
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
        ScriptGlue.Log_LogMessage(LogLevel.Trace, message);
    }
    
    /// <summary>
    /// Logs an info message.
    /// </summary>
    /// <param name="message">The message to log.</param>
    public static void Info(string message)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Info, message);
    }
    
    /// <summary>
    /// Logs a warning message.
    /// </summary>
    /// <param name="message">The message to log.</param>
    public static void Warning(string message)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Warning, message);
    }
    
    /// <summary>
    /// Logs an error message.
    /// </summary>
    /// <param name="message">The message to log.</param>
    public static void Error(string message)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Error, message);
    }
    
    /// <summary>
    /// Logs a critical error message.
    /// </summary>
    /// <param name="message">The message to log.</param>
    public static void Critical(string message)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Critical, message);
    }
    
    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as a trace message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    public static void Trace(object obj)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Trace, obj.ToString());
    }
    
    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as an info message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    public static void Info(object obj)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Info, obj.ToString());
    }

    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as a warning message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    public static void Warning(object obj)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Warning, obj.ToString());
    }

    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as an error message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    public static void Error(object obj)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Error, obj.ToString());
    }
    
    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as a critical error message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    public static void Critical(object obj)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Critical, obj.ToString());
    }

    /// <summary>
    /// Logs the give exception.
    /// </summary>
    /// <param name="exception">The exception to log.</param>
    public static void Exception(Exception exception)
    {
        ScriptGlue.Log_LogException(exception);
    }
}
