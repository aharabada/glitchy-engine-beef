using System;

namespace GlitchyEngine.Editor;

[AttributeUsage(AttributeTargets.Class | AttributeTargets.Struct, AllowMultiple = true)]
public sealed class CustomEditorAttribute : Attribute
{
    public Type Type { get; private set; }

    public CustomEditorAttribute(Type type)
    {
        Type = type;
    }
}
