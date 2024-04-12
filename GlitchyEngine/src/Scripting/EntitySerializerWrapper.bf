using System;
using Mono;
using GlitchyEngine.Core;
using GlitchyEngine.Serialization;

namespace GlitchyEngine.Scripting;

using internal GlitchyEngine.Scripting;

class EntitySerializerWrapper : ScriptClass
{
	function void CreateSerializationContextMethod(void* serializerPtr, MonoException** exception);
	function void ClearSerializationContextMethod(void* serializerPtr, MonoException** exception);
	function void DestroySerializationContextMethod(void* serializerPtr, MonoException** exception);

	function void SerializeMethod(MonoObject* entity, void* serializedObjPtr, void* serializerPtr, MonoException** exception);
	function void DeserializeMethod(MonoObject* entity, void* serializedObjPtr, void* serializerPtr, MonoException** exception);
	function void SerializeStaticMethod(MonoReflectionType* type, void* serializedObjPtr, void* serializerPtr, MonoException** exception);
	function void DeserializeStaticMethod(MonoReflectionType* type, void* serializedObjPtr, void* serializerPtr, MonoException** exception);

	private CreateSerializationContextMethod _createSerializationContextMethod;
	private ClearSerializationContextMethod _clearSerializationContextMethod;
	private DestroySerializationContextMethod _destroySerializationContextMethod;

	private SerializeMethod _serializeMethod;
	private DeserializeMethod _deserializeMethod;
	private SerializeStaticMethod _serializeStaticMethod;
	private DeserializeStaticMethod _deserializeStaticMethod;

	[AllowAppend]
	public this(StringView classNamespace, StringView className, MonoImage* image) : base(classNamespace, className, image)
	{
		_serializeMethod = (SerializeMethod)GetMethodThunk("Serialize", 3);

		if (_serializeMethod == null)
		{
			Log.EngineLogger.Error("EntitySerializer has no \"Serialize\" method.");
		}

		_deserializeMethod = (DeserializeMethod)GetMethodThunk("Deserialize", 3);

		if (_serializeMethod == null)
		{
			Log.EngineLogger.Error("EntitySerializer has no \"Deserialize\" method.");
		}

		_serializeStaticMethod = (SerializeStaticMethod)GetMethodThunk("SerializeStaticFields", 3);

		if (_serializeStaticMethod == null)
		{
			Log.EngineLogger.Error("EntitySerializer has no \"SerializeStaticStatic\" method.");
		}

		_deserializeStaticMethod = (SerializeStaticMethod)GetMethodThunk("DeserializeStaticFields", 3);

		if (_deserializeStaticMethod == null)
		{
			Log.EngineLogger.Error("EntitySerializer has no \"DeserializeStaticStatic\" method.");
		}

		_createSerializationContextMethod = (CreateSerializationContextMethod)GetMethodThunk("CreateSerializationContext", 1);

		if (_createSerializationContextMethod == null)
		{
			Log.EngineLogger.Error("EntitySerializer has no \"CreateSerializationContext\" method.");
		}

		_clearSerializationContextMethod = (ClearSerializationContextMethod)GetMethodThunk("ClearSerializationContext", 1);

		if (_clearSerializationContextMethod == null)
		{
			Log.EngineLogger.Error("EntitySerializer has no \"ClearSerializationContext\" method.");
		}

		_destroySerializationContextMethod = (DestroySerializationContextMethod)GetMethodThunk("DestroySerializationContext", 1);

		if (_destroySerializationContextMethod == null)
		{
			Log.EngineLogger.Error("EntitySerializer has no \"DestroySerializationContext\" method.");
		}
	}

	public void CreateSerializationContext(ScriptInstanceSerializer serializer)
	{
		void* serializerPtr = Internal.UnsafeCastToPtr(serializer);

		MonoException* exception = null;
		_createSerializationContextMethod(serializerPtr, &exception);

		if (exception != null)
			ScriptEngine.[Friend]HandleMonoException(exception, null);
	}
	
	public void ClearSerializationContext(ScriptInstanceSerializer serializer)
	{
		void* serializerPtr = Internal.UnsafeCastToPtr(serializer);

		MonoException* exception = null;
		_clearSerializationContextMethod(serializerPtr, &exception);

		if (exception != null)
			ScriptEngine.[Friend]HandleMonoException(exception, null);
	}

	public void DestroySerializationContext(ScriptInstanceSerializer serializer)
	{
		void* serializerPtr = Internal.UnsafeCastToPtr(serializer);

		MonoException* exception = null;
		_destroySerializationContextMethod(serializerPtr, &exception);

		if (exception != null)
			ScriptEngine.[Friend]HandleMonoException(exception, null);
	}

	public void Serialize(ScriptInstance instance, SerializedObject serializedObject)
	{
		void* serializedObjectPtr = Internal.UnsafeCastToPtr(serializedObject);
		void* serializerPtr = Internal.UnsafeCastToPtr(serializedObject.Serializer);

		MonoException* exception = null;
		_serializeMethod(instance.[Friend]_instance, serializedObjectPtr, serializerPtr, &exception);

		if (exception != null)
			ScriptEngine.[Friend]HandleMonoException(exception, instance);
	}
	
	public void SerializeStatic(ScriptClass @class, SerializedObject serializedObject)
	{
		void* serializedObjectPtr = Internal.UnsafeCastToPtr(serializedObject);
		void* serializerPtr = Internal.UnsafeCastToPtr(serializedObject.Serializer);

		MonoType* type = Mono.mono_class_get_type(@class.[Friend]_monoClass);
		MonoReflectionType* reflectionType = Mono.mono_type_get_object(ScriptEngine.[Friend]s_AppDomain, type);
		
		MonoException* exception = null;
		_serializeStaticMethod(reflectionType, serializedObjectPtr, serializerPtr, &exception);

		if (exception != null)
			ScriptEngine.[Friend]HandleMonoException(exception, null);
	}

	public void Deserialize(ScriptInstance instance, SerializedObject serializedObject)
	{
		void* serializedObjectPtr = Internal.UnsafeCastToPtr(serializedObject);
		void* serializerPtr = Internal.UnsafeCastToPtr(serializedObject.Serializer);

		MonoException* exception = null;
		_deserializeMethod(instance.[Friend]_instance, serializedObjectPtr, serializerPtr, &exception);

		if (exception != null)
			ScriptEngine.[Friend]HandleMonoException(exception, instance);
	}
	
	public void DeserializeStatic(ScriptClass @class, SerializedObject serializedObject)
	{
		void* serializedObjectPtr = Internal.UnsafeCastToPtr(serializedObject);
		void* serializerPtr = Internal.UnsafeCastToPtr(serializedObject.Serializer);
		
		MonoType* type = Mono.mono_class_get_type(@class.[Friend]_monoClass);
		MonoReflectionType* reflectionType = Mono.mono_type_get_object(ScriptEngine.[Friend]s_AppDomain, type);
		
		MonoException* exception = null;
		_deserializeStaticMethod(reflectionType, serializedObjectPtr, serializerPtr, &exception);

		if (exception != null)
			ScriptEngine.[Friend]HandleMonoException(exception, null);
	}
}
