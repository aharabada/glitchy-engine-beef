using System;
using System.Collections.Generic;
using System.Text;

namespace ScriptCore.Math.Attributes;

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

public class SwizzleVectorAttribute : Attribute
{
    public SwizzleVectorAttribute()
    {
    }
}
