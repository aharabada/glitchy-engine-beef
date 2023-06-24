using Bon;
using System;

namespace GlitchyEngine.Math.FancyMath;

[BonTarget]
[Vector<half, 2>]
[ComparableVector<half, 2>]
[VectorMath<half, 2>]
[SwizzleVector(2, "GlitchyEngine.Math.FancyMath.half")]
public struct half2
{
	public static explicit operator float2(half2 value)
	{
		return float2((float)value.X, (float)value.Y);
	}
}

[BonTarget]
[Vector<half, 3>]
[ComparableVector<half, 3>]
[VectorMath<half, 3>]
[SwizzleVector(3, "GlitchyEngine.Math.FancyMath.half")]
public struct half3
{
	public static explicit operator float3(half3 value)
	{
		return float3((float)value.X, (float)value.Y, (float)value.Z);
	}
}

[BonTarget]
[Vector<half, 4>]
[ComparableVector<half, 4>]
[VectorMath<half, 4>]
[SwizzleVector(4, "GlitchyEngine.Math.FancyMath.half")]
public struct half4
{
	public static explicit operator float4(half4 value)
	{
		return float4((float)value.X, (float)value.Y, (float)value.Z, (float)value.W);
	}
}
