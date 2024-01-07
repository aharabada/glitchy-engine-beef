using GlitchyEngine.Editor;
using System;
using System.Collections.Generic;
using System.Reflection;
using GlitchyEngine.Core;
using GlitchyEngine.Extensions;

namespace GlitchyEngine.Serialization;

[Flags]
public enum SerializationType : uint
{
    None = 0,

    Bool = 1u << 31,

    TextTypes = 1 << 30,

    Char = TextTypes | 1,
    String = TextTypes | 2,

    Number = 1 << 29,
    Integer = Number | 1 << 28,

    Int8 = Integer | 1,
    Int16 = Integer | 2,
    Int32 = Integer | 3,
    Int64 = Integer | 4,
    UInt8 = Integer | 5,
    UInt16 = Integer | 6,
    UInt32 = Integer | 7,
    UInt64 = Integer | 8,

    FloatingPoint = Number | 1 << 27,

    Float = FloatingPoint | 1,
    Double = FloatingPoint | 2,
    Decimal = FloatingPoint | 3,

    Enum = 1 << 26,

    EntityReference = 1 << 25,
    ComponentReference = 1 << 24,

    ObjectReference = 1 << 23,
}

public static class SerializationTypeExtension
{
    public static bool CanConvertTo(this SerializationType currentType, SerializationType targetType)
    {
        if (currentType.HasFlag(SerializationType.Number) && targetType.HasFlag(SerializationType.Number))
            return true;

        return false;
    }

    public static Type? GetTypeInstance(this SerializationType currentType)
    {
        return currentType switch
        {
            SerializationType.Bool => typeof(bool),
            SerializationType.Char => typeof(char),
            SerializationType.String => typeof(string),
            SerializationType.Int8 => typeof(sbyte),
            SerializationType.Int16 => typeof(short),
            SerializationType.Int32 => typeof(int),
            SerializationType.Int64 => typeof(long),
            SerializationType.UInt8 => typeof(byte),
            SerializationType.UInt16 => typeof(ushort),
            SerializationType.UInt32 => typeof(uint),
            SerializationType.UInt64 => typeof(ulong),
            SerializationType.Float => typeof(float),
            SerializationType.Double => typeof(double),
            SerializationType.Decimal => typeof(decimal),
            SerializationType.Enum => typeof(Enum),
            SerializationType.EntityReference => typeof(UUID),
            SerializationType.ComponentReference => typeof(UUID),
            SerializationType.ObjectReference => typeof(UUID),
            _ => null
        };
    }
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
