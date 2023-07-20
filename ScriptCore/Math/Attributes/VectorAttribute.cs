using System;
using System.Collections.Generic;
using System.Text;

namespace GlitchyEngine.Math.Attributes;

[AttributeUsage(AttributeTargets.Struct)]
public class VectorAttribute : Attribute
{
    public Type Type { get; set; }
    public int ComponentCount { get; set; }
    
    public string TypeBase { get; set; }

    public VectorAttribute(Type type, int componentCount, string typeBase)
    {
        Type = type;
        ComponentCount = componentCount;
        TypeBase = typeBase;
    }
}

[AttributeUsage(AttributeTargets.Struct)]
public class ComparableVectorAttribute : Attribute { }
[AttributeUsage(AttributeTargets.Struct)]
public class VectorMathAttribute : Attribute { }
[AttributeUsage(AttributeTargets.Struct)]
public class VectorLogicAttribute : Attribute { }

[AttributeUsage(AttributeTargets.Struct, AllowMultiple = true)]
public class VectorCastAttribute : Attribute
{
    public Type TargetType { get; set; }

    public bool IsExplicit { get; set; }

    public VectorCastAttribute(Type targetType, bool isExplicit)
    {
        TargetType = targetType;
        IsExplicit = isExplicit;
    }
}
