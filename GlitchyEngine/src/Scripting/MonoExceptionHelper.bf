using System;
using GlitchyEngine.Core;
using Mono;

namespace GlitchyEngine.Scripting;


public class MonoExceptionHelper : RefCounter
{
	private String _fullName ~ delete _;

	private String _message ~ delete _;

	private String _stackTrace ~ delete _;
	/// The clean stack trace only contains the Managed Stack (the full trace contains one line for the native-to-managed entry)
	private StringView _cleanStackTrace;

	private MonoExceptionHelper _innerException ~ _?.ReleaseRef();

	public StringView FullName => _fullName;
	public StringView Message => _message;

	public StringView StackTrace => _stackTrace;
	public StringView CleanStackTrace => _cleanStackTrace;

	public MonoExceptionHelper InnerException => _innerException;

	public UUID Instance { get; set; }

	public this(MonoException* exception)
	{
		MonoObject* exObject = (MonoObject*)exception;

		MonoClass* monoClass = Mono.mono_object_get_class(exObject);

		StringView classNamespace = .(Mono.mono_class_get_namespace(monoClass));
		StringView className = .(Mono.mono_class_get_name(monoClass));
		_fullName = new $"{classNamespace}.{className}";

		GetMessage(exObject, monoClass);

		GetStackTrace(exception);

		GetInnerException(exObject, monoClass);
	}

	private void GetMessage(MonoObject* exceptionObject, MonoClass* monoClass)
	{
		var messageProperty = Mono.mono_class_get_property_from_name(monoClass, "Message");

		MonoObject* message = Mono.mono_property_get_value(messageProperty, exceptionObject, null, null);
		char8* exMessage = Mono.mono_string_to_utf8((.)message);

		_message = new String(exMessage);

		Mono.mono_free(exMessage);
	}

	private void GetStackTrace(MonoException* exception)
	{
		char8* stacktracePtr = Mono.mono_exception_get_managed_backtrace(exception);
		_stackTrace = new String(stacktracePtr);

		int entryIndex = _stackTrace.IndexOf("at (wrapper native-to-managed)");

		if (entryIndex != -1)
			_cleanStackTrace = _stackTrace.Substring(0, entryIndex);
		else
			_cleanStackTrace = _stackTrace;
	}

	private void GetInnerException(MonoObject* exceptionObject, MonoClass* monoClass)
	{
		MonoProperty* innerExceptionProperty = Mono.mono_class_get_property_from_name(monoClass, "InnerException");
		
		MonoObject* innerException = Mono.mono_property_get_value(innerExceptionProperty, exceptionObject, null, null);

		if (innerException != null)
			_innerException = new MonoExceptionHelper((MonoException*)innerException);
	}
}
