using GlitchyEngine.Core;
using System;
using System.Diagnostics;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using static GlitchyEngine.Log;

namespace GlitchyEngine;

/// <summary>
/// Provides methods to log messages to the Engine Console.
/// </summary>
public class Log
{
    /// <summary>
    /// The severity of the log message.
    /// </summary>
    [EngineClass("GlitchLog.LogLevel")]
    internal enum LogLevel : byte
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
    /// <param name="callerMemberName">Name of the calling member.</param>
    public static void Trace(string message, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0, [CallerMemberName]string callerMemberName = "")
    {
        ScriptGlue.Log_LogMessage(LogLevel.Trace, ScriptGlue.CurrentEntityId, message, callerFilePath, callerMemberName, callerLineNumber, 0);
    }
    
    /// <summary>
    /// Logs an info message.
    /// </summary>
    /// <param name="message">The message to log.</param>
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    /// <param name="callerMemberName">Name of the calling member.</param>
    public static void Info(string message, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0, [CallerMemberName]string callerMemberName = "")
    {
        ScriptGlue.Log_LogMessage(LogLevel.Info, ScriptGlue.CurrentEntityId, message, callerFilePath, callerMemberName, callerLineNumber, 0);
    }
    
    /// <summary>
    /// Logs a warning message.
    /// </summary>
    /// <param name="message">The message to log.</param>
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    /// <param name="callerMemberName">Name of the calling member.</param>
    public static void Warning(string message, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0, [CallerMemberName]string callerMemberName = "")
    {
        ScriptGlue.Log_LogMessage(LogLevel.Warning, ScriptGlue.CurrentEntityId, message, callerFilePath, callerMemberName, callerLineNumber, 0);
    }
    
    /// <summary>
    /// Logs an error message.
    /// </summary>
    /// <param name="message">The message to log.</param>
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    /// <param name="callerMemberName">Name of the calling member.</param>
    public static void Error(string message, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0, [CallerMemberName]string callerMemberName = "")
    {
        ScriptGlue.Log_LogMessage(LogLevel.Error, ScriptGlue.CurrentEntityId, message, callerFilePath, callerMemberName, callerLineNumber, 0);
    }
    
    /// <summary>
    /// Logs a critical error message.
    /// </summary>
    /// <param name="message">The message to log.</param>
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    /// <param name="callerMemberName">Name of the calling member.</param>
    public static void Critical(string message, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0, [CallerMemberName]string callerMemberName = "")
    {
        ScriptGlue.Log_LogMessage(LogLevel.Critical, ScriptGlue.CurrentEntityId, message, callerFilePath, callerMemberName, callerLineNumber, 0);
    }
    
    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as a trace message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    /// <param name="callerMemberName">Name of the calling member.</param>
    public static void Trace(object obj, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0, [CallerMemberName]string callerMemberName = "")
    {
        ScriptGlue.Log_LogMessage(LogLevel.Trace, ScriptGlue.CurrentEntityId, obj.ToString(), callerFilePath, callerMemberName, callerLineNumber, 0);
    }
    
    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as an info message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    /// <param name="callerMemberName">Name of the calling member.</param>
    public static void Info(object obj, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0, [CallerMemberName]string callerMemberName = "")
    {
        ScriptGlue.Log_LogMessage(LogLevel.Info, ScriptGlue.CurrentEntityId, obj.ToString(), callerFilePath, callerMemberName, callerLineNumber, 0);
    }

    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as a warning message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    /// <param name="callerMemberName">Name of the calling member.</param>
    public static void Warning(object obj, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0, [CallerMemberName]string callerMemberName = "")
    {
        ScriptGlue.Log_LogMessage(LogLevel.Warning, ScriptGlue.CurrentEntityId, obj.ToString(), callerFilePath, callerMemberName, callerLineNumber, 0);
    }

    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as an error message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    /// <param name="callerMemberName">Name of the calling member.</param>
    public static void Error(object obj, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0, [CallerMemberName]string callerMemberName = "")
    {
        ScriptGlue.Log_LogMessage(LogLevel.Error, ScriptGlue.CurrentEntityId, obj.ToString(), callerFilePath, callerMemberName, callerLineNumber, 0);
    }
    
    /// <summary>
    /// Serializes the given object (using <see cref="object.ToString"/>) and logs it as a critical error message.
    /// </summary>
    /// <param name="obj">The object to serialize.</param>
    /// <param name="callerFilePath">File path of the caller.</param>
    /// <param name="callerLineNumber">Line number of the caller.</param>
    /// <param name="callerMemberName">Name of the calling member.</param>
    public static void Critical(object obj, [CallerFilePath]string callerFilePath = "", [CallerLineNumber]int callerLineNumber = 0, [CallerMemberName]string callerMemberName = "")
    {
        ScriptGlue.Log_LogMessage(LogLevel.Critical, ScriptGlue.CurrentEntityId, obj.ToString(), callerFilePath, callerMemberName, callerLineNumber, 0);
    }

    [DebuggerDisplay("{ToString(),raw}")]
    [StructLayout(LayoutKind.Sequential, Pack = 0)]
    [EngineClass("GlitchyEngine.Scripting.ScriptGlue.GlueStackFrameInfo")]
    internal struct StackFrameInfo
    {
        public Native.StringView FileName;
        public Native.StringView MethodSignature;
        public int LineNumber;
        public int ColumnNumber;
    }

    static string GetFullSignature(MethodBase method)
    {
        var typeName = method.DeclaringType?.FullName ?? "<unknown>";
        var parameters = string.Join(", ",
            method.GetParameters().Select(p => $"{p.ParameterType.Name}"));

        return $"{typeName}.{method.Name}({parameters})";
    }

    /// <summary>
    /// Logs the give exception.
    /// </summary>
    /// <param name="exception">The exception to log.</param>
    public static void Exception(Exception exception)
    {
        StackTrace st = new StackTrace(exception, true);
        StackFrame[] frames = st.GetFrames();

        StackFrameInfo[] stackFrameInfos = new StackFrameInfo[frames.Length];

        // We only need StackFrameInfo for exception logging, so it's okay to manually handle the marshalling here.
        foreach (StackFrame stackFrame in frames)
        {
            MethodBase? method = stackFrame.GetMethod();
            string methodSignature = method != null ? GetFullSignature(method) : "<unknown>";
            stackFrameInfos[frames.IndexOf(stackFrame)] = new StackFrameInfo
            {
                FileName = Native.StringView.FromManagedString(stackFrame.GetFileName()),
                MethodSignature = Native.StringView.FromManagedString(methodSignature),
                LineNumber = stackFrame.GetFileLineNumber(),
                ColumnNumber = stackFrame.GetFileColumnNumber()
            };
        }

        unsafe
        {
            fixed (StackFrameInfo* stackFrames = stackFrameInfos)
            {
                ScriptGlue.Log_LogException(ScriptGlue.CurrentEntityId, exception.GetType().FullName, exception.Message, stackFrames, stackFrameInfos.Length);
            }
        }

        foreach (StackFrameInfo stackFrameInfo in stackFrameInfos)
        {
            Native.StringView.FreeNativeMemory(stackFrameInfo.FileName);
        }
    }
}
