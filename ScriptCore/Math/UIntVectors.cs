using System;
using GlitchyEngine.Math;
using GlitchyEngine.Math.Attributes;

namespace GlitchyEngine.Math;

// TODO: Currently no VectorMath-Attribute because -uint results in long

/// <summary>
/// Represents a vector with two 32-bit unsigned integer values.
/// </summary>
[Vector(typeof(uint), 2, "uint")]
[VectorLogic]
[ComparableVector]
[VectorCast(typeof(int2), true)]
[VectorCast(typeof(float2), true)]
public partial struct uint2
{
    public static uint2 operator ~(uint2 value)
    {
        return new uint2(~value.X, ~value.Y);
    }
}

/// <summary>
/// Represents a vector with three 32-bit unsigned integer values.
/// </summary>
[Vector(typeof(uint), 3, "uint")]
[VectorLogic]
[ComparableVector]
[VectorCast(typeof(int3), true)]
[VectorCast(typeof(float3), true)]
public partial struct uint3
{
    public static uint3 operator ~(uint3 value)
    {
        return new uint3(~value.X, ~value.Y, ~value.Z);
    }
}

/// <summary>
/// Represents a vector with four 32-bit unsigned integer values.
/// </summary>
[Vector(typeof(uint), 4, "uint")]
[VectorLogic]
[ComparableVector]
[VectorCast(typeof(int4), true)]
[VectorCast(typeof(float4), true)]
public partial struct uint4
{
    public static uint4 operator ~(uint4 value)
    {
        return new uint4(~value.X, ~value.Y, ~value.Z, ~value.W);
    }
}
