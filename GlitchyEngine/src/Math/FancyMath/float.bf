using Bon;
using System;

namespace GlitchyEngine.Math.FancyMath;

[BonTarget]
[Vector<float, 2>]
[ComparableVector<float, 2>]
[VectorMath<float, 2>]
[SwizzleVector(2, "GlitchyEngine.Math.FancyMath.float")]
public struct float2
{
	public static implicit operator int2(float2 value)
	{
		return int2((int32)value.X, (int32)value.Y);
	}

	public static explicit operator half2(float2 value)
	{
		return half2((half)value.X, (half)value.Y);
	}
}

[BonTarget]
[Vector<float, 3>]
[ComparableVector<float, 3>]
[VectorMath<float, 3>]
[SwizzleVector(3, "GlitchyEngine.Math.FancyMath.float")]
public struct float3
{
	public static implicit operator int3(float3 value)
	{
		return int3((int32)value.X, (int32)value.Y, (int32)value.Z);
	}

	public static explicit operator half3(float3 value)
	{
		return half3((half)value.X, (half)value.Y, (half)value.Z);
	}
}

[BonTarget]
[Vector<float, 4>]
[ComparableVector<float, 4>]
[VectorMath<float, 4>]
[SwizzleVector(4, "GlitchyEngine.Math.FancyMath.float")]
public struct float4
{
	public static implicit operator int4(float4 value)
	{
		return int4((int32)value.X, (int32)value.Y, (int32)value.Z, (int32)value.W);
	}
	
	public static explicit operator half4(float4 value)
	{
		return half4((half)value.X, (half)value.Y, (half)value.Z, (half)value.W);
	}
}