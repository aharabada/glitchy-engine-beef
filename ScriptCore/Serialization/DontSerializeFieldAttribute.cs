using System;

namespace GlitchyEngine.Serialization;

/// <summary>
/// Specifies that the field should not be serialized.
/// </summary>
/// <seealso cref="SerializeFieldAttribute"/>
[AttributeUsage(AttributeTargets.Field)]
public sealed class DontSerializeFieldAttribute : Attribute
{
}
