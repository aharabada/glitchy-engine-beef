using System;
using GlitchyEngine.Core;
using GlitchyEngine.Serialization;

namespace GlitchyEngine.Scripting;

using internal GlitchyEngine.Scripting;

class EntitySerializerWrapper : NewScriptClass
{
	function void CreateSerializationContextMethod(void* serializerPtr);
	//function void ClearSerializationContextMethod(void* serializerPtr);
	function void DestroySerializationContextMethod(void* serializerPtr);

	function void SerializeMethod(UUID entityId, void* serializedObjPtr, void* serializerPtr);
	function void DeserializeMethod(UUID entityId, void* serializedObjPtr, void* serializerPtr);
	function void SerializeStaticMethod(char8* fullTypeName, void* serializedObjPtr, void* serializerPtr);
	function void DeserializeStaticMethod(char8* fullTypeName, void* serializedObjPtr, void* serializerPtr);

	private CreateSerializationContextMethod _createSerializationContextMethod;
	//private ClearSerializationContextMethod _clearSerializationContextMethod;
	private DestroySerializationContextMethod _destroySerializationContextMethod;

	private SerializeMethod _serializeMethod;
	private DeserializeMethod _deserializeMethod;
	private SerializeStaticMethod _serializeStaticMethod;
	private DeserializeStaticMethod _deserializeStaticMethod;

	[AllowAppend]
	public this() : base("GlitchyEngine.Serialization.EntitySerializer", .Empty, .None, false)
	{
		CoreClrHelper.GetFunctionPointerUnmanagedCallersOnly("GlitchyEngine.ScriptGlue, ScriptCore", "CreateSerializationContext", out _createSerializationContextMethod);
		CoreClrHelper.GetFunctionPointerUnmanagedCallersOnly("GlitchyEngine.ScriptGlue, ScriptCore", "DestroySerializationContext", out _destroySerializationContextMethod);
		CoreClrHelper.GetFunctionPointerUnmanagedCallersOnly("GlitchyEngine.ScriptGlue, ScriptCore", "EntitySerializer_Serialize", out _serializeMethod);
		CoreClrHelper.GetFunctionPointerUnmanagedCallersOnly("GlitchyEngine.ScriptGlue, ScriptCore", "EntitySerializer_Deserialize", out _deserializeMethod);
		CoreClrHelper.GetFunctionPointerUnmanagedCallersOnly("GlitchyEngine.ScriptGlue, ScriptCore", "EntitySerializer_SerializeStaticFields", out _serializeStaticMethod);
		CoreClrHelper.GetFunctionPointerUnmanagedCallersOnly("GlitchyEngine.ScriptGlue, ScriptCore", "EntitySerializer_DeserializeStaticFields", out _deserializeStaticMethod);
	}

	public void CreateSerializationContext(ScriptInstanceSerializer serializer)
	{
		void* serializerPtr = Internal.UnsafeCastToPtr(serializer);

		_createSerializationContextMethod(serializerPtr);
	}
	
	/*public void ClearSerializationContext(ScriptInstanceSerializer serializer)
	{
		void* serializerPtr = Internal.UnsafeCastToPtr(serializer);

		MonoException* exception = null;
		_clearSerializationContextMethod(serializerPtr, &exception);

		if (exception != null)
			ScriptEngine.[Friend]HandleMonoException(exception, null);
	}*/

	public void DestroySerializationContext(ScriptInstanceSerializer serializer)
	{
		void* serializerPtr = Internal.UnsafeCastToPtr(serializer);

		_destroySerializationContextMethod(serializerPtr);
	}

	public void Serialize(NewScriptInstance instance, SerializedObject serializedObject)
	{
		void* serializedObjectPtr = Internal.UnsafeCastToPtr(serializedObject);
		void* serializerPtr = Internal.UnsafeCastToPtr(serializedObject.Serializer);

		_serializeMethod(instance.EntityId, serializedObjectPtr, serializerPtr);
	}
	
	public void SerializeStatic(NewScriptClass @class, SerializedObject serializedObject)
	{
		void* serializedObjectPtr = Internal.UnsafeCastToPtr(serializedObject);
		void* serializerPtr = Internal.UnsafeCastToPtr(serializedObject.Serializer);

		_serializeStaticMethod(@class.FullName.CStr(), serializedObjectPtr, serializerPtr);
	}

	public void Deserialize(NewScriptInstance instance, SerializedObject serializedObject)
	{
		void* serializedObjectPtr = Internal.UnsafeCastToPtr(serializedObject);
		void* serializerPtr = Internal.UnsafeCastToPtr(serializedObject.Serializer);

		_deserializeMethod(instance.EntityId, serializedObjectPtr, serializerPtr);
	}
	
	public void DeserializeStatic(NewScriptClass @class, SerializedObject serializedObject)
	{
		void* serializedObjectPtr = Internal.UnsafeCastToPtr(serializedObject);
		void* serializerPtr = Internal.UnsafeCastToPtr(serializedObject.Serializer);
		
		_deserializeStaticMethod(@class.FullName.CStr(), serializedObjectPtr, serializerPtr);
	}
}
