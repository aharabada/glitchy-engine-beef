using GlitchyEngine.Math.Attributes;

namespace GlitchyEngine.Math;

/// <summary>
/// A matrix with 2 rows and 2 columns of 32-bit signed integer values.
/// </summary>
[Matrix(typeof(int), 2, 2, "int")]
[MatrixLogic]
[MatrixCast(typeof(float), true)]
[MatrixCast(typeof(uint), true)]
public partial struct int2x2
{
}

/// <summary>
/// A matrix with 3 rows and 3 columns of 32-bit signed integer values.
/// </summary>
[Matrix(typeof(int), 3, 3, "int")]
[MatrixLogic]
[MatrixCast(typeof(float), true)]
[MatrixCast(typeof(uint), true)]
public partial struct int3x3
{
}

/// <summary>
/// A matrix with 4 rows and 4 columns of 32-bit signed integer values.
/// </summary>
[Matrix(typeof(int), 4, 4, "int")]
[MatrixLogic]
[MatrixCast(typeof(float), true)]
[MatrixCast(typeof(uint), true)]
public partial struct int4x4
{
}
