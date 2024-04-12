using System;
using Mono;
using GlitchyEngine.Core;
using GlitchyEngine.Serialization;

namespace GlitchyEngine.Scripting;

using internal GlitchyEngine.Scripting;

class EntitySerializerWrapper : ScriptClass
{
	function MonoObject* SerializeMethod(MonoObject* entity, void* contextPtr, MonoException** exception);
	function MonoObject* DeserializeMethod(MonoObject* entity, void* contextPtr, MonoException** exception);
	function MonoObject* SerializeStaticMethod(MonoReflectionType* type, void* contextPtr, MonoException** exception);
	function MonoObject* DeserializeStaticMethod(MonoReflectionType* type, void* contextPtr, MonoException** exception);

	private SerializeMethod _serializeMethod;
	private DeserializeMethod _deserializeMethod;
	private SerializeStaticMethod _serializeStaticMethod;
	private DeserializeStaticMethod _deserializeStaticMethod;

	[AllowAppend]
	public this(StringView classNamespace, StringView className, MonoImage* image) : base(classNamespace, className, image)
	{
		_serializeMethod = (SerializeMethod)GetMethodThunk("Serialize", 2);

		if (_serializeMethod == null)
		{
			Log.EngineLogger.Error("EntitySerializer has no \"Serialize\" method.");
		}

		_deserializeMethod = (DeserializeMethod)GetMethodThunk("Deserialize", 2);

		if (_serializeMethod == null)
		{
			Log.EngineLogger.Error("EntitySerializer has no \"Deserialize\" method.");
		}

		_serializeStaticMethod = (SerializeStaticMethod)GetMethodThunk("SerializeStaticFields", 2);

		if (_serializeStaticMethod == null)
		{
			Log.EngineLogger.Error("EntitySerializer has no \"SerializeStaticStatic\" method.");
		}

		_deserializeStaticMethod = (SerializeStaticMethod)GetMethodThunk("DeserializeStaticFields", 2);

		if (_deserializeStaticMethod == null)
		{
			Log.EngineLogger.Error("EntitySerializer has no \"DeserializeStaticStatic\" method.");
		}
	}

	public void Serialize(ScriptInstance instance, SerializedObject context)
	{
		void* thisPtr = Internal.UnsafeCastToPtr(context);

		MonoException* exception = null;
		_serializeMethod(instance.[Friend]_instance, thisPtr, &exception);

		if (exception != null)
			ScriptEngine.[Friend]HandleMonoException(exception, instance);
	}
	
	public void SerializeStatic(ScriptClass @class, SerializedObject context)
	{
		void* thisPtr = Internal.UnsafeCastToPtr(context);

		MonoException* exception = null;

		MonoType* type = Mono.mono_class_get_type(@class.[Friend]_monoClass);
		MonoReflectionType* reflectionType = Mono.mono_type_get_object(ScriptEngine.[Friend]s_AppDomain, type);

		_serializeStaticMethod(reflectionType, thisPtr, &exception);

		if (exception != null)
			ScriptEngine.[Friend]HandleMonoException(exception, null);
	}

	public void Deserialize(ScriptInstance instance, SerializedObject context)
	{
		void* thisPtr = Internal.UnsafeCastToPtr(context);

		MonoException* exception = null;
		_deserializeMethod(instance.[Friend]_instance, thisPtr, &exception);

		if (exception != null)
			ScriptEngine.[Friend]HandleMonoException(exception, instance);
	}
	
	public void DeserializeStatic(ScriptClass @class, SerializedObject context)
	{
		void* thisPtr = Internal.UnsafeCastToPtr(context);

		MonoException* exception = null;
		
		MonoType* type = Mono.mono_class_get_type(@class.[Friend]_monoClass);
		MonoReflectionType* reflectionType = Mono.mono_type_get_object(ScriptEngine.[Friend]s_AppDomain, type);

		_deserializeStaticMethod(reflectionType, thisPtr, &exception);

		if (exception != null)
			ScriptEngine.[Friend]HandleMonoException(exception, null);
	}
}
