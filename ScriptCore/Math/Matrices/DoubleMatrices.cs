using GlitchyEngine.Math.Attributes;

namespace GlitchyEngine.Math;

/// <summary>
/// A matrix with 2 rows and 2 columns of double-precision floating-point values.
/// </summary>
[Matrix(typeof(double), 2, 2, "double")]
[ComparableMatrix]
[MatrixMath]
[MatrixVectorMultiplication(typeof(double2))]
[MatrixCast(typeof(float), true)]
public partial struct double2x2
{
    /// <summary>
    /// A 2x2 matrix whose elements are all equal to zero.
    /// </summary>
    public static readonly double2x2 Zero = new(0.0);
    
    /// <summary>
    /// A 2x2 matrix whose elements are all equal to one.
    /// </summary>
    public static readonly double2x2 One = new(1.0);

    /// <summary>
    /// The identity 2x2 matrix.
    /// </summary>
    public static readonly double2x2 Identity = new(
        1.0, 0.0,
        0.0, 1.0);
}

/// <summary>
/// A matrix with 3 rows and 3 columns of double-precision floating-point values.
/// </summary>
[Matrix(typeof(double), 3, 3, "double")]
[ComparableMatrix]
[MatrixMath]
[MatrixVectorMultiplication(typeof(double3))]
[MatrixCast(typeof(float), true)]
public partial struct double3x3
{
    /// <summary>
    /// A 3x3 matrix whose elements are all equal to zero.
    /// </summary>
    public static readonly double3x3 Zero = new(0.0);
    
    /// <summary>
    /// A 3x3 matrix whose elements are all equal to one.
    /// </summary>
    public static readonly double3x3 One = new(1.0);
    
    /// <summary>
    /// The identity 3x3 matrix.
    /// </summary>
    public static readonly double3x3 Identity = new(
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0);
}

/// <summary>
/// A matrix with 4 rows and 4 columns of double-precision floating-point values.
/// </summary>
[Matrix(typeof(double), 4, 4, "double")]
[ComparableMatrix]
[MatrixMath]
[MatrixVectorMultiplication(typeof(double4))]
[MatrixCast(typeof(float), true)]
public partial struct double4x4
{
    /// <summary>
    /// A 4x4 matrix whose elements are all equal to zero.
    /// </summary>
    public static readonly double4x4 Zero = new(0.0);
    
    /// <summary>
    /// A 4x4 matrix whose elements are all equal to one.
    /// </summary>
    public static readonly double4x4 One = new(1.0);
    
    /// <summary>
    /// The identity 4x4 matrix.
    /// </summary>
    public static readonly double4x4 Identity = new(
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0);
}
