using Bon;
using System;

namespace GlitchyEngine.Math;

[BonTarget]
[Vector<int32, 2>]
[ComparableVector<int32, 2>]
[VectorMath<int32, 2>]
[SwizzleVector(2, "GlitchyEngine.Math.int")]
public struct int2
{
	public const int2 Zero  = .(0, 0);
	public const int2 UnitX = .(1, 0);
	public const int2 UnitY = .(0, 1);
	public const int2 One   = .(1, 1);
	
	public static implicit operator float2(int2 value)
	{
		return float2(value.X, value.Y);
	}

	public static explicit operator uint2(int2 value)
	{
		return uint2((uint32)value.X, (uint32)value.Y);
	}
}

[BonTarget]
[Vector<int32, 3>]
[ComparableVector<int32, 3>]
[VectorMath<int32, 3>]
[SwizzleVector(3, "GlitchyEngine.Math.int")]
public struct int3
{
	public const int3 Zero     = .(0, 0, 0);
	public const int3 UnitX    = .(1, 0, 0);
	public const int3 UnitY    = .(0, 1, 0);
	public const int3 UnitZ    = .(0, 0, 1);
	public const int3 One      = .(1, 1, 1);
	
	public static implicit operator float3(int3 value)
	{
		return float3(value.X, value.Y, value.Z);
	}

	public static explicit operator uint3(int3 value)
	{
		return uint3((uint32)value.X, (uint32)value.Y, (uint32)value.Z);
	}
}

[BonTarget]
[Vector<int32, 4>]
[ComparableVector<int32, 4>]
[VectorMath<int32, 4>]
[SwizzleVector(4, "GlitchyEngine.Math.int")]
public struct int4
{
	public const int4 Zero	= .(0, 0, 0, 0);
	public const int4 UnitX	= .(1, 0, 0, 0);
	public const int4 UnitY	= .(0, 1, 0, 0);
	public const int4 UnitZ	= .(0, 0, 1, 0);
	public const int4 UnitW	= .(0, 0, 0, 1);
	public const int4 One	= .(1, 1, 1, 1);
	
	public static implicit operator float4(int4 value)
	{
		return float4(value.X, value.Y, value.Z, value.W);
	}

	public static explicit operator uint4(int4 value)
	{
		return uint4((uint32)value.X, (uint32)value.Y, (uint32)value.Z, (uint32)value.W);
	}
}

[BonTarget]
[Vector<uint32, 2>]
[ComparableVector<uint32, 2>]
//[VectorMath<uint32, 2>]
[SwizzleVector(2, "GlitchyEngine.Math.uint")]
public struct uint2
{
	public const uint2 Zero  = .(0, 0);
	public const uint2 UnitX = .(1, 0);
	public const uint2 UnitY = .(0, 1);
	public const uint2 One   = .(1, 1);

	public static implicit operator float2(uint2 value)
	{
		return float2(value.X, value.Y);
	}

	public static explicit operator int2(uint2 value)
	{
		return int2((int32)value.X, (int32)value.Y);
	}
}

[BonTarget]
[Vector<uint32, 3>]
[ComparableVector<uint32, 3>]
//[VectorMath<uint32, 3>]
[SwizzleVector(3, "GlitchyEngine.Math.uint")]
public struct uint3
{
	public const uint3 Zero     = .(0, 0, 0);
	public const uint3 UnitX    = .(1, 0, 0);
	public const uint3 UnitY    = .(0, 1, 0);
	public const uint3 UnitZ    = .(0, 0, 1);
	public const uint3 One      = .(1, 1, 1);

	public static implicit operator float3(uint3 value)
	{
		return float3(value.X, value.Y, value.Z);
	}

	public static explicit operator int3(uint3 value)
	{
		return int3((int32)value.X, (int32)value.Y, (int32)value.Z);
	}
}

[BonTarget]
[Vector<uint32, 4>]
[ComparableVector<uint32, 4>]
//[VectorMath<uint32, 4>]
[SwizzleVector(4, "GlitchyEngine.Math.uint")]
public struct uint4
{
	public const uint4 Zero		= .(0, 0, 0, 0);
	public const uint4 UnitX	= .(1, 0, 0, 0);
	public const uint4 UnitY	= .(0, 1, 0, 0);
	public const uint4 UnitZ	= .(0, 0, 1, 0);
	public const uint4 UnitW	= .(0, 0, 0, 1);
	public const uint4 One		= .(1, 1, 1, 1);
	
	public static implicit operator float4(uint4 value)
	{
		return float4(value.X, value.Y, value.Z, value.W);
	}

	public static explicit operator int4(uint4 value)
	{
		return int4((int32)value.X, (int32)value.Y, (int32)value.Z, (int32)value.W);
	}
}
