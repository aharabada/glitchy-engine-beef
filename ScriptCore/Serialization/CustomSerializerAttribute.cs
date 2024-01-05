using System;
using System.Collections.Generic;
using System.Text;

namespace GlitchyEngine.Serialization;

[AttributeUsage(AttributeTargets.Class | AttributeTargets.Struct, AllowMultiple = true)]
public sealed class CustomSerializerAttribute : Attribute
{
    public Type Type { get; private set; }

    public CustomSerializerAttribute(Type type)
    {
        Type = type;
    }
}
