using System;

namespace GlitchyEngine.Serialization;

/// <summary>
/// Specifies that the field is to be serialized.
/// </summary>
/// <seealso cref="DontSerializeFieldAttribute"/>
[AttributeUsage(AttributeTargets.Field)]
public sealed class SerializeFieldAttribute : Attribute
{
}
