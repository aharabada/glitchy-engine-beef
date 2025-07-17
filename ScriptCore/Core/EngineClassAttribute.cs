using System;

namespace GlitchyEngine.Core;

[AttributeUsage(AttributeTargets.Class | AttributeTargets.Struct | AttributeTargets.Enum, AllowMultiple = true)]
public class EngineClassAttribute : Attribute
{
    public string EngineClassName { get; }

    public EngineClassAttribute(string engineClassName)
    {
        EngineClassName = engineClassName;
    }
}