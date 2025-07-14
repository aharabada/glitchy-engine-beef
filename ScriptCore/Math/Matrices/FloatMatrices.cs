using System;
using GlitchyEngine.Math.Attributes;

namespace GlitchyEngine.Math;

/// <summary>
/// A matrix with 2 rows and 2 columns of single-precision floating-point values.
/// </summary>
/// <remarks>
/// The matrix is stored in a column-major order.
/// The positions of the elements is the following:
/// <table>
/// <tr>
/// <td>M11</td> <td>M12</td>
/// </tr>
/// <tr>
/// <td>M21</td> <td>M22</td>
/// </tr>
/// </table>
/// The memory order is M11, M21, M12, M22.
/// </remarks>
[Matrix(typeof(float), 2, 2, "float")]
[ComparableMatrix]
[MatrixMath]
[MatrixVectorMultiplication(typeof(float2))]
[MatrixCast(typeof(double), true)]
[MatrixCast(typeof(Half), true)]
[MatrixCast(typeof(int), true)]
[MatrixCast(typeof(uint), true)]
public partial struct float2x2
{
    /// <summary>
    /// A 2x2 matrix whose elements are all equal to zero.
    /// </summary>
    public static readonly float2x2 Zero = new(0.0f);
    
    /// <summary>
    /// A 2x2 matrix whose elements are all equal to one.
    /// </summary>
    public static readonly float2x2 One = new(1.0f);
    
    /// <summary>
    /// The identity 2x2 matrix.
    /// </summary>
    public static readonly float2x2 Identity = new(
        1.0f, 0.0f,
        0.0f, 1.0f);
    
    /// <summary>
    /// Creates a new 2x2 matrix that represents a rotation by a specified angle.
    /// </summary>
    /// <param name="angle">The angle of rotation.</param>
    /// <returns>The matrix representing the rotation.</returns>
    public static float2x2 Rotation(float angle)
    {
        float cos = Math.cos(angle);
        float sin = Math.sin(angle);
        
        return new float2x2(cos, -sin, sin, cos);
    }
}

/// <summary>
/// A matrix with 3 rows and 3 columns of single-precision floating-point values.
/// </summary>
[Matrix(typeof(float), 3, 3, "float")]
[ComparableMatrix]
[MatrixMath]
[MatrixVectorMultiplication(typeof(float3))]
[MatrixCast(typeof(double), true)]
[MatrixCast(typeof(Half), true)]
[MatrixCast(typeof(int), true)]
[MatrixCast(typeof(uint), true)]
public partial struct float3x3
{
    /// <summary>
    /// A 3x3 matrix whose elements are all equal to zero.
    /// </summary>
    public static readonly float3x3 Zero = new(0.0f);
    
    /// <summary>
    /// A 3x3 matrix whose elements are all equal to one.
    /// </summary>
    public static readonly float3x3 One = new(1.0f);
    
    /// <summary>
    /// The identity 3x3 matrix.
    /// </summary>
    public static readonly float3x3 Identity = new(
        1.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 1.0f);
}

/// <summary>
/// A matrix with 4 rows and 4 columns of single-precision floating-point values.
/// </summary>
[Matrix(typeof(float), 4, 4, "float")]
[ComparableMatrix]
[MatrixMath]
[MatrixVectorMultiplication(typeof(float4))]
[MatrixCast(typeof(double), true)]
[MatrixCast(typeof(Half), true)]
[MatrixCast(typeof(int), true)]
[MatrixCast(typeof(uint), true)]
public partial struct float4x4
{
    /// <summary>
    /// A 4x4 matrix whose elements are all equal to zero.
    /// </summary>
    public static readonly float4x4 Zero = new(0.0f);
    
    /// <summary>
    /// A 4x4 matrix whose elements are all equal to one.
    /// </summary>
    public static readonly float4x4 One = new(1.0f);
    
    /// <summary>
    /// The identity 4x4 matrix.
    /// </summary>
    public static readonly float4x4 Identity = new(
        1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 1.0f);
}
