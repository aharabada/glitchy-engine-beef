using System;

namespace GlitchyEngine.Math.Attributes;

/// <summary>
/// Generates fields for the components of a vector as well as basic methods like constructors, type casts and equality checks.
/// </summary>
[AttributeUsage(AttributeTargets.Struct)]
public class VectorAttribute : Attribute
{
    /// <summary>
    /// The Type of the vectors components.
    /// </summary>
    public Type Type { get; set; }
    /// <summary>
    /// Number of components in the vectors (valid values are in the range of 2 to 4).
    /// </summary>
    public int ComponentCount { get; set; }
    
    /// <summary>
    /// The base name of the vector.
    /// </summary>
    public string TypeBase { get; set; }

    /// <summary>
    /// Creates a new instance of the <see cref="VectorAttribute"/> class.
    /// </summary>
    /// <param name="type"><inheritdoc cref="Type"/></param>
    /// <param name="componentCount"><inheritdoc cref="ComponentCount"/></param>
    /// <param name="typeBase"><inheritdoc cref="TypeBase"/></param>
    public VectorAttribute(Type type, int componentCount, string typeBase)
    {
        Type = type;
        ComponentCount = componentCount;
        TypeBase = typeBase;
    }
}

/// <summary>
/// Generates comparison operators (>, <, >= and <=) for the vectors type.
/// </summary>
[AttributeUsage(AttributeTargets.Struct)]
public class ComparableVectorAttribute : Attribute { }

/// <summary>
/// Generates component wise math operators (+, -, *, / and %) for the vectors type.
/// </summary>
[AttributeUsage(AttributeTargets.Struct)]
public class VectorMathAttribute : Attribute { }

/// <summary>
/// Generates component wise logic operators (&, ^ and |) for the vectors type.
/// </summary>
[AttributeUsage(AttributeTargets.Struct)]
public class VectorLogicAttribute : Attribute { }

/// <summary>
/// Generates a cast cast from the vector type to the specified target type.
/// </summary>
[AttributeUsage(AttributeTargets.Struct, AllowMultiple = true)]
public class VectorCastAttribute : Attribute
{
    /// <summary>
    /// The type of the target vector type.
    /// </summary>
    public Type TargetType { get; set; }

    /// <summary>
    /// If <see cref="true"/> the cast will be explicit; if <see cref="false"/> it will an implicit cast.
    /// </summary>
    public bool IsExplicit { get; set; }

    /// <summary>
    /// Creates a new instance of the <see cref="VectorCastAttribute"/> class.
    /// </summary>
    /// <param name="targetType"><inheritdoc cref="TargetType"/></param>
    /// <param name="isExplicit"><inheritdoc cref="IsExplicit"/></param>
    public VectorCastAttribute(Type targetType, bool isExplicit)
    {
        TargetType = targetType;
        IsExplicit = isExplicit;
    }
}
