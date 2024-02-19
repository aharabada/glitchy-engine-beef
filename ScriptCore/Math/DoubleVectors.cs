using System;
using GlitchyEngine.Math;
using GlitchyEngine.Math.Attributes;

namespace GlitchyEngine.Math;

/// <summary>
/// Represents a vector with two double-precision floating-point values.
/// </summary>
[Vector(typeof(double), 2, "double")]
[VectorMath]
[ComparableVector]
[VectorCast(typeof(float2), true)]
public partial struct double2
{
}

/// <summary>
/// Represents a vector with three double-precision floating-point values.
/// </summary>
[Vector(typeof(double), 3, "double")]
[VectorMath]
[ComparableVector]
[VectorCast(typeof(float3), true)]
public partial struct double3
{
}

/// <summary>
/// Represents a vector with four double-precision floating-point values.
/// </summary>
[Vector(typeof(double), 4, "double")]
[VectorMath]
[ComparableVector]
[VectorCast(typeof(float4), true)]
public partial struct double4
{
}
