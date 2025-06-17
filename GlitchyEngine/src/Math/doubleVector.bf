using Bon;
using System;

namespace GlitchyEngine.Math;

[BonTarget, CRepr]
[Vector<double, 2>]
[ComparableVector<double, 2>]
[VectorMath<double, 2>]
[SwizzleVector(2, "GlitchyEngine.Math.double")]
public struct double2
{
	public const double2 Zero  = .(0, 0);
	public const double2 UnitX = .(1, 0);
	public const double2 UnitY = .(0, 1);
	public const double2 One   = .(1, 1);
	
	public static explicit operator int2(double2 value)
	{
		return int2((int32)value.X, (int32)value.Y);
	}

	public static explicit operator uint2(double2 value)
	{
		return uint2((uint32)value.X, (uint32)value.Y);
	}

	public static explicit operator half2(double2 value)
	{
		return half2((half)value.X, (half)value.Y);
	}
	
	public static explicit operator float2(double2 value)
	{
		return float2((float)value.X, (float)value.Y);
	}
}

[BonTarget, CRepr]
[Vector<double, 3>]
[ComparableVector<double, 3>]
[VectorMath<double, 3>]
[SwizzleVector(3, "GlitchyEngine.Math.double")]
public struct double3
{
	public const double3 Zero     = .(0, 0, 0);
	public const double3 UnitX    = .(1, 0, 0);
	public const double3 UnitY    = .(0, 1, 0);
	public const double3 UnitZ    = .(0, 0, 1);
	public const double3 One      = .(1, 1, 1);
	
	public const double3 Forward  = .(0, 0, 1);	
	public const double3 Backward = .(0, 0, -1);	
	public const double3 Left     = .(-1, 0, 0); 	
	public const double3 Right    = .(1, 0, 0);  	
	public const double3 Up       = .(0, 1, 0); 	
	public const double3 Down     = .(0, -1, 0);
	
	public static explicit operator int3(double3 value)
	{
		return int3((int32)value.X, (int32)value.Y, (int32)value.Z);
	}

	public static explicit operator uint3(double3 value)
	{
		return uint3((uint32)value.X, (uint32)value.Y, (uint32)value.Z);
	}

	public static explicit operator half3(double3 value)
	{
		return half3((half)(float)value.X, (half)(float)value.Y, (half)(float)value.Z);
	}
	
	public static explicit operator float3(double3 value)
	{
		return float3((float)value.X, (float)value.Y, (float)value.Z);
	}
}

[BonTarget, CRepr]
[Vector<double, 4>]
[ComparableVector<double, 4>]
[VectorMath<double, 4>]
[SwizzleVector(4, "GlitchyEngine.Math.double")]
public struct double4
{
	public const double4 Zero	= .(0, 0, 0, 0);
	public const double4 UnitX	= .(1, 0, 0, 0);
	public const double4 UnitY	= .(0, 1, 0, 0);
	public const double4 UnitZ	= .(0, 0, 1, 0);
	public const double4 UnitW	= .(0, 0, 0, 1);
	public const double4 One	= .(1, 1, 1, 1);
	
	public static explicit operator int4(double4 value)
	{
		return int4((int32)value.X, (int32)value.Y, (int32)value.Z, (int32)value.W);
	}

	public static explicit operator uint4(double4 value)
	{
		return uint4((uint32)value.X, (uint32)value.Y, (uint32)value.Z, (uint32)value.W);
	}
	
	public static explicit operator half4(double4 value)
	{
		return half4((half)(float)value.X, (half)(float)value.Y, (half)(float)value.Z, (half)(float)value.W);
	}
	
	public static explicit operator float4(double4 value)
	{
		return float4((float)value.X, (float)value.Y, (float)value.Z, (float)value.W);
	}
}