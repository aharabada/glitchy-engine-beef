using GlitchyEngine.Editor;
using System;
using System.Collections.Generic;
using System.Reflection;
using GlitchyEngine.Core;
using GlitchyEngine.Extensions;

namespace GlitchyEngine.Serialization;

public enum SerializationType : int
{
    None,

    Bool,

    Char,
    String,

    Int8,
    Int16,
    Int32,
    Int64,
    UInt8,
    UInt16,
    UInt32,
    UInt64,

    Float,
    Double,
    Decimal,

    Enum,

    EntityReference,
    ComponentReference,

    ObjectReference
}

internal static class EntitySerializer
{
    internal static void Serialize(Entity entity, IntPtr internalContext)
    {
        SerializedObject obj = new SerializedObject(internalContext, UUID.Zero, new Dictionary<object, SerializedObject>());
        obj.Serialize(entity);
    }
    
    internal static void Deserialize(Entity entity, IntPtr internalContext)
    {
        DeserializationObject obj = new DeserializationObject(internalContext, UUID.Zero, new Dictionary<UUID, DeserializationObject>());
        obj.Deserialize(entity);
    }

    /// <summary>
    /// Returns whether or not the field described by the given <see cref="fieldInfo"/> should be serialized or not.
    /// </summary>
    internal static bool SerializeField(FieldInfo fieldInfo)
    {
        // TODO: We want to be able to serialize static fields in the future!
        if (fieldInfo.IsStatic)
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
