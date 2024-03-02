using System;
using GlitchyEngine.Math.Attributes;

namespace GlitchyEngine.Math;

/// <summary>
/// Represents a vector with two half-precision floating-point values.
/// </summary>
/// <inheritdoc cref="Half" select="remarks" />
[Vector(typeof(Half), 2, "half")]
[VectorMath]
[ComparableVector]
[VectorCast(typeof(float2), true)]
public partial struct half2
{
}

/// <summary>
/// Represents a vector with three half-precision floating-point values.
/// </summary>
/// <inheritdoc cref="Half" select="remarks" />
[Vector(typeof(Half), 3, "half")]
[VectorMath]
[ComparableVector]
[VectorCast(typeof(float3), true)]
public partial struct half3
{
}

/// <summary>
/// Represents a vector with four half-precision floating-point values.
/// </summary>
/// <inheritdoc cref="Half" select="remarks" />
[Vector(typeof(Half), 4, "half")]
[VectorMath]
[ComparableVector]
[VectorCast(typeof(float4), true)]
public partial struct half4
{
}
