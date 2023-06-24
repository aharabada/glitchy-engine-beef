using Bon;
using System;

namespace GlitchyEngine.Math.FancyMath;

[BonTarget]
[Vector<int32, 2>]
[ComparableVector<int32, 2>]
[VectorMath<int32, 2>]
[SwizzleVector(2, "GlitchyEngine.Math.FancyMath.int")]
public struct int2
{
	public static implicit operator float2(int2 value)
	{
		return float2(value.X, value.Y);
	}
}

[BonTarget]
[Vector<int32, 3>]
[ComparableVector<int32, 3>]
[VectorMath<int32, 3>]
[SwizzleVector(3, "GlitchyEngine.Math.FancyMath.int")]
public struct int3
{
	public static implicit operator float3(int3 value)
	{
		return float3(value.X, value.Y, value.Z);
	}
}

[BonTarget]
[Vector<int32, 4>]
[ComparableVector<int32, 4>]
[VectorMath<int32, 4>]
[SwizzleVector(4, "GlitchyEngine.Math.FancyMath.int")]
public struct int4
{
	public static implicit operator float4(int4 value)
	{
		return float4(value.X, value.Y, value.Z, value.W);
	}
}