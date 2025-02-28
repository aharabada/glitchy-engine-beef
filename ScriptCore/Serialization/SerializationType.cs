using System;
using GlitchyEngine.Core;

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

    // Used for everything that inherits from EngineObject (Assets, Components, Entities)
    EngineObjectReference = 1 << 25,

    ObjectReference = 1 << 24,
}

public static class SerializationTypeExtension
{
    public static bool CanConvertTo(this SerializationType currentType, SerializationType targetType)
    {
        if (currentType.HasFlag(SerializationType.Number) && targetType.HasFlag(SerializationType.Number))
            return true;

        return false;
    }

    public static Type? GetTypeInstance(this SerializationType currentType) =>
        currentType switch
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
            SerializationType.EngineObjectReference => typeof(UUID),
            SerializationType.ObjectReference => typeof(UUID),
            _ => null
        };
}
