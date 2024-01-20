using System;
using System.Diagnostics;
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
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    public static void Trace(string message, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Trace, message, callerFilePath, callerLineNumber);
    }
    
    /// <summary>
    /// Logs an info message.
    /// </summary>
    /// <param name="message">The message to log.</param>
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    public static void Info(string message, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Info, message, callerFilePath, callerLineNumber);
    }
    
    /// <summary>
    /// Logs a warning message.
    /// </summary>
    /// <param name="message">The message to log.</param>
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    public static void Warning(string message, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Warning, message, callerFilePath, callerLineNumber);
    }
    
    /// <summary>
    /// Logs an error message.
    /// </summary>
    /// <param name="message">The message to log.</param>
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    public static void Error(string message, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Error, message, callerFilePath, callerLineNumber);
    }
    
    /// <summary>
    /// Logs a critical error message.
    /// </summary>
    /// <param name="message">The message to log.</param>
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    public static void Critical(string message, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Critical, message, callerFilePath, callerLineNumber);
    }
    
    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as a trace message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    public static void Trace(object obj, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Trace, obj.ToString(), callerFilePath, callerLineNumber);
    }
    
    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as an info message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    public static void Info(object obj, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Info, obj.ToString(), callerFilePath, callerLineNumber);
    }

    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as a warning message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    public static void Warning(object obj, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Warning, obj.ToString(), callerFilePath, callerLineNumber);
    }

    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as an error message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    public static void Error(object obj, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Error, obj.ToString(), callerFilePath, callerLineNumber);
    }
    
    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as a critical error message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    public static void Critical(object obj, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0)
    {
        ScriptGlue.Log_LogMessage(LogLevel.Critical, obj.ToString(), callerFilePath, callerLineNumber);
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
