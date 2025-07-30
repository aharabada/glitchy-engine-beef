using System;
using GlitchyEngine.Core;

namespace GlitchyEngine.Scripting;


public class ScriptException
{
	private String _fullName ~ delete:append _;

	private String _message ~ delete:append _;

	private String _stackTrace ~ delete:append _;
	/// The clean stack trace only contains the Managed Stack (the full trace contains one line for the native-to-managed entry)
	private StringView _cleanStackTrace;

	//TODO
	//private ScriptException _innerException ~ _?.ReleaseRef();

	public StringView FullName => _fullName;
	public StringView Message => _message;

	public StringView StackTrace => _stackTrace;
	public StringView CleanStackTrace => _cleanStackTrace;

	//public ScriptException InnerException => _innerException;

	public UUID EntityId { get; set; }

	[AllowAppend]
	public this(UUID entityId, StringView fullExceptionClassName, StringView message, StringView stackTrace)
	{
		String allocFullExceptionClassName = append String(fullExceptionClassName);
		String allocMessage = append String(message);
		String allocStackTrace = append String(stackTrace);

		_fullName = allocFullExceptionClassName;
		_message = allocMessage;
		_stackTrace = allocStackTrace;

		// TODO
		_cleanStackTrace = _stackTrace;
	}
}
