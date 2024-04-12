using GlitchyEngine.Editor;
using System;
using System.Collections.Generic;
using System.Reflection;
using GlitchyEngine.Core;
using GlitchyEngine.Extensions;

namespace GlitchyEngine.Serialization;

internal static class EntitySerializer
{
    internal static void Serialize(Entity entity, IntPtr internalContext)
    {
        SerializedObject obj = new SerializedObject(internalContext, false, UUID.Zero, new Dictionary<object, SerializedObject>());
        obj.Serialize(entity);
    }
    
    internal static void Deserialize(Entity entity, IntPtr internalContext)
    {
        DeserializationObject obj = new DeserializationObject(internalContext, false, UUID.Zero, new Dictionary<UUID, DeserializationObject>());
        obj.Deserialize(entity);
    }
    
    internal static void SerializeStaticFields(Type type, IntPtr internalContext)
    {
        SerializedObject obj = new SerializedObject(internalContext, true, UUID.Zero, new Dictionary<object, SerializedObject>());
        obj.Serialize(type);
    }

    internal static void DeserializeStaticFields(Type type, IntPtr internalContext)
    {
        DeserializationObject obj = new DeserializationObject(internalContext, true, UUID.Zero, new Dictionary<UUID, DeserializationObject>());
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
