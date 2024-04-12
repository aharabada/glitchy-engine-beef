using GlitchyEngine.Editor;
using System;
using System.Collections.Generic;
using System.Reflection;
using GlitchyEngine.Core;
using GlitchyEngine.Extensions;

namespace GlitchyEngine.Serialization;

internal static class EntitySerializer
{
    private static Dictionary<IntPtr, Dictionary<object, SerializedObject>> SerializationObjects = new(); 
    private static Dictionary<IntPtr, Dictionary<UUID, DeserializationObject>> DeserializationObjects = new(); 
    
    internal static void CreateSerializationContext(IntPtr engineSerializer)
    {
        if (SerializationObjects.ContainsKey(engineSerializer))
        {
            ClearSerializationContext(engineSerializer);
            return;
        }
        
        SerializationObjects.Add(engineSerializer, new Dictionary<object, SerializedObject>());
        DeserializationObjects.Add(engineSerializer, new Dictionary<UUID, DeserializationObject>());
    }
    
    internal static void ClearSerializationContext(IntPtr engineSerializer)
    {
        SerializationObjects[engineSerializer].Clear();
        DeserializationObjects[engineSerializer].Clear();
    }

    internal static void DestroySerializationContext(IntPtr engineSerializer)
    {
        SerializationObjects.Remove(engineSerializer);
        DeserializationObjects.Remove(engineSerializer);
    }
    
    internal static void Serialize(Entity entity, IntPtr engineObject, IntPtr engineSerializer)
    {
        SerializedObject obj = new SerializedObject(engineObject, false, UUID.Zero, SerializationObjects[engineSerializer]);
        obj.Serialize(entity);
    }
    
    internal static void Deserialize(Entity entity, IntPtr engineObject, IntPtr engineSerializer)
    {
        DeserializationObject obj = new DeserializationObject(engineObject, false, UUID.Zero, DeserializationObjects[engineSerializer]);
        obj.Deserialize(entity);
    }
    
    internal static void SerializeStaticFields(Type type, IntPtr engineObject, IntPtr engineSerializer)
    {
        SerializedObject obj = new SerializedObject(engineObject, true, UUID.Zero, SerializationObjects[engineSerializer]);
        obj.Serialize(type);
    }

    internal static void DeserializeStaticFields(Type type, IntPtr engineObject, IntPtr engineSerializer)
    {
        DeserializationObject obj = new DeserializationObject(engineObject, true, UUID.Zero, DeserializationObjects[engineSerializer]);
        obj.Deserialize(type);
    }

    /// <summary>
    /// Returns whether or not the field described by the given <see cref="fieldInfo"/> should be serialized or not.
    /// </summary>
    /// <param name="fieldInfo">The field info for which to check whether the field should be serialized or not.</param>
    /// <param name="staticSerialization">If <see langword="true"/> the only Static fields can be serialized; if <see langword="false"/> only instance fields can be serialized.</param>
    internal static bool SerializeField(FieldInfo fieldInfo, bool staticSerialization)
    {
        if (staticSerialization != fieldInfo.IsStatic)
            return false;

        var serializeField = fieldInfo.HasCustomAttribute<SerializeFieldAttribute>();
        var dontSerializeField = fieldInfo.HasCustomAttribute<DontSerializeFieldAttribute>();
        //var hideField = fieldInfo.HasCustomAttribute<HideInEditorAttribute>();
        var showField = fieldInfo.HasCustomAttribute<ShowInEditorAttribute>();

        if (fieldInfo.IsPublic)
        {
            if (dontSerializeField)
                return false;

            return true;
        }
        
        if (serializeField)
            return true;
        
        if (showField && !dontSerializeField)
            return true;

        return false;
    }
}
