using GlitchyEngine.Math.Attributes;

namespace GlitchyEngine.Math;

/// <summary>
/// A matrix with 2 rows and 2 columns of 32-bit unsigned integer values.
/// </summary>
[Matrix(typeof(uint), 2, 2, "uint")]
[MatrixLogic]
[MatrixCast(typeof(float), true)]
[MatrixCast(typeof(int), true)]
public partial struct uint2x2
{
}

/// <summary>
/// A matrix with 3 rows and 3 columns of 32-bit unsigned integer values.
/// </summary>
[Matrix(typeof(uint), 3, 3, "uint")]
[MatrixLogic]
[MatrixCast(typeof(float), true)]
[MatrixCast(typeof(int), true)]
public partial struct uint3x3
{
}

/// <summary>
/// A matrix with 4 rows and 4 columns of 32-bit unsigned integer values.
/// </summary>
[Matrix(typeof(uint), 4, 4, "uint")]
[MatrixLogic]
[MatrixCast(typeof(float), true)]
[MatrixCast(typeof(int), true)]
public partial struct uint4x4
{
}
