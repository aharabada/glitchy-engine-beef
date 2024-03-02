using GlitchyEngine.Math.Attributes;

namespace GlitchyEngine.Math;

/// <summary>
/// A matrix with 2 rows and 2 columns of boolean values.
/// </summary>
[Matrix(typeof(bool), 2, 2, "bool")]
[MatrixLogic]
public partial struct bool2x2
{
}

/// <summary>
/// A matrix with 3 rows and 3 columns of boolean values.
/// </summary>
[Matrix(typeof(bool), 3, 3, "bool")]
[MatrixLogic]
public partial struct bool3x3
{
}

/// <summary>
/// A matrix with 4 rows and 4 columns of boolean values.
/// </summary>
[Matrix(typeof(bool), 4, 4, "bool")]
[MatrixLogic]
public partial struct bool4x4
{
}
