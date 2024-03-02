using GlitchyEngine.Math.Attributes;

namespace GlitchyEngine.Math;

/// <summary>
/// A matrix with 2 rows and 2 columns of half-precision floating-point values.
/// </summary>
[Matrix(typeof(Half), 2, 2, "half")]
[ComparableMatrix]
[MatrixMath]
[MatrixCast(typeof(float), true)]
public partial struct half2x2
{
    /// <summary>
    /// A 2x2 matrix whose elements are all equal to zero.
    /// </summary>
    public static readonly half2x2 Zero = new((Half)0.0f);
    
    /// <summary>
    /// A 2x2 matrix whose elements are all equal to one.
    /// </summary>
    public static readonly half2x2 One = new((Half)1.0f);

    /// <summary>
    /// The identity 2x2 matrix.
    /// </summary>
    public static readonly half2x2 Identity = new(
        (Half)1.0f, (Half)0.0f,
        (Half)0.0f, (Half)1.0f);
}

/// <summary>
/// A matrix with 3 rows and 3 columns of half-precision floating-point values.
/// </summary>
[Matrix(typeof(Half), 3, 3, "half")]
[ComparableMatrix]
[MatrixMath]
[MatrixCast(typeof(float), true)]
public partial struct half3x3
{
    /// <summary>
    /// A 3x3 matrix whose elements are all equal to zero.
    /// </summary>
    public static readonly half3x3 Zero = new((Half)0.0f);
    
    /// <summary>
    /// A 3x3 matrix whose elements are all equal to one.
    /// </summary>
    public static readonly half3x3 One = new((Half)1.0f);
    
    /// <summary>
    /// The identity 3x3 matrix.
    /// </summary>
    public static readonly half3x3 Identity = new(
        (Half)1.0f, (Half)0.0f, (Half)0.0f,
        (Half)0.0f, (Half)1.0f, (Half)0.0f,
        (Half)0.0f, (Half)0.0f, (Half)1.0f);
}

/// <summary>
/// A matrix with 4 rows and 4 columns of half-precision floating-point values.
/// </summary>
[Matrix(typeof(Half), 4, 4, "half")]
[ComparableMatrix]
[MatrixMath]
[MatrixCast(typeof(float), true)]
public partial struct half4x4
{
    /// <summary>
    /// A 4x4 matrix whose elements are all equal to zero.
    /// </summary>
    public static readonly half4x4 Zero = new((Half)0.0f);
    
    /// <summary>
    /// A 4x4 matrix whose elements are all equal to one.
    /// </summary>
    public static readonly half4x4 One = new((Half)1.0f);
    
    /// <summary>
    /// The identity 4x4 matrix.
    /// </summary>
    public static readonly half4x4 Identity = new(
        (Half)1.0f, (Half)0.0f, (Half)0.0f, (Half)0.0f,
        (Half)0.0f, (Half)1.0f, (Half)0.0f, (Half)0.0f,
        (Half)0.0f, (Half)0.0f, (Half)1.0f, (Half)0.0f,
        (Half)0.0f, (Half)0.0f, (Half)0.0f, (Half)1.0f);
}
