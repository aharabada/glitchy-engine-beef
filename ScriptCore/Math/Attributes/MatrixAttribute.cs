using System;

namespace GlitchyEngine.Math.Attributes;

/// <summary>
/// Specifies that fields for the components of a matrix should be generated as well as basic methods like constructors, type casts and equality checks.
/// </summary>
[AttributeUsage(AttributeTargets.Struct)]
public sealed class MatrixAttribute : Attribute
{
    /// <summary>
    /// The Type of the matrices components.
    /// </summary>
    public Type Type { get; }
    /// <summary>
    /// The number of rows the matrix has.
    /// </summary>
    public int Rows { get; }
    /// <summary>
    /// The number of columns the matrix has.
    /// </summary>
    public int Columns { get; }
    /// <summary>
    /// The base name of the matrix. (Name of matrix without the row and column count)
    /// </summary>
    public string BaseName { get; }
    
    /// <summary>
    /// Creates a new instance of the <see cref="MatrixAttribute"/> class.
    /// </summary>
    /// <param name="type"><inheritdoc cref="Type"/></param>
    /// <param name="rows"><inheritdoc cref="Rows"/></param>
    /// <param name="columns"><inheritdoc cref="Columns"/></param>
    /// <param name="baseName"><inheritdoc cref="BaseName"/></param>
    public MatrixAttribute(Type type, int rows, int columns, string baseName)
    {
        Type = type;
        Rows = rows;
        Columns = columns;
        BaseName = baseName;
    }
}

/// <summary>
/// Specifies that the matrix type should have comparison operators (>, <, >= and <=) generated for it.
/// </summary>
[AttributeUsage(AttributeTargets.Struct)]
public sealed class ComparableMatrixAttribute : Attribute
{
}

/// <summary>
/// Specifies that the matrix type should have component wise math operators (+, -) generated for it.
/// </summary>
[AttributeUsage(AttributeTargets.Struct)]
public class MatrixMathAttribute : Attribute { }

/// <summary>
/// Specifies that the matrix type should have component wise logic operators (&, ^ and |) generated for it.
/// </summary>
[AttributeUsage(AttributeTargets.Struct)]
public class MatrixLogicAttribute : Attribute { }

/// <summary>
/// Generates a multiplication overload for matrix type with the specified vector type.
/// </summary>
[AttributeUsage(AttributeTargets.Struct, AllowMultiple = true)]
public class MatrixVectorMultiplicationAttribute : Attribute
{
    /// <summary>
    /// The type of the vector that will be multiplied with the matrix.
    /// </summary>
    public Type VectorType { get; set; }

    /// <summary>
    /// Creates a new instance of the <see cref="MatrixVectorMultiplicationAttribute"/> class.
    /// </summary>
    /// <param name="vectorType"><inheritdoc cref="VectorType"/></param>
    public MatrixVectorMultiplicationAttribute(Type vectorType)
    {
        VectorType = vectorType;
    }
}

/// <summary>
/// Generates a cast cast from the matrix type to the specified target type.
/// </summary>
[AttributeUsage(AttributeTargets.Struct, AllowMultiple = true)]
public class MatrixCastAttribute : Attribute
{
    /// <summary>
    /// The type of the target matrix type.
    /// </summary>
    public Type TargetType { get; set; }

    /// <summary>
    /// If <see cref="true"/> the cast will be explicit; if <see cref="false"/> it will an implicit cast.
    /// </summary>
    public bool IsExplicit { get; set; }

    /// <summary>
    /// Creates a new instance of the <see cref="MatrixCastAttribute"/> class.
    /// </summary>
    /// <param name="targetType"><inheritdoc cref="TargetType"/></param>
    /// <param name="isExplicit"><inheritdoc cref="IsExplicit"/></param>
    public MatrixCastAttribute(Type targetType, bool isExplicit)
    {
        TargetType = targetType;
        IsExplicit = isExplicit;
    }
}
