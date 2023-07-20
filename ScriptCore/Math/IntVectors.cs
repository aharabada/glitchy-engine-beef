using System;
using GlitchyEngine.Math;
using GlitchyEngine.Math.Attributes;

namespace GlitchyEngine.Math;

[Vector(typeof(int), 2, "int")]
[VectorMath]
[VectorLogic]
[ComparableVector]
[VectorCast(typeof(float2), true)]
[VectorCast(typeof(uint2), true)]
public partial struct int2
{
    public static int2 operator ~(int2 value)
    {
        return new int2(~value.X, ~value.Y);
    }
}

[Vector(typeof(int), 3, "int")]
[VectorMath]
[VectorLogic]
[ComparableVector]
[VectorCast(typeof(float3), true)]
[VectorCast(typeof(uint3), true)]
public partial struct int3
{
    public static int3 operator ~(int3 value)
    {
        return new int3(~value.X, ~value.Y, ~value.Z);
    }
}

[Vector(typeof(int), 4, "int")]
[VectorMath]
[VectorLogic]
[ComparableVector]
[VectorCast(typeof(float4), true)]
[VectorCast(typeof(uint4), true)]
public partial struct int4
{
    public static int4 operator ~(int4 value)
    {
        return new int4(~value.X, ~value.Y, ~value.Z, ~value.W);
    }
}
