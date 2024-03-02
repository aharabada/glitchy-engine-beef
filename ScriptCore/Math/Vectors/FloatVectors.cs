using System;
using System.Collections.Generic;
using System.Numerics;
using System.Runtime.InteropServices;
using System.Text;
using GlitchyEngine.Math;
using GlitchyEngine.Math.Attributes;

namespace GlitchyEngine.Math;

/// <summary>
/// Represents a vector with two single-precision floating-point values.
/// </summary>
[Vector(typeof(float), 2, "float")]
[ComparableVector]
[VectorMath]
[VectorCast(typeof(int2), true)]
[VectorCast(typeof(double2), true)]
[VectorCast(typeof(half2), true)]
public partial struct float2
{
    /// <summary>
    /// A vector whose elements are all equal to zero.
    /// </summary>
    public static readonly float2 Zero = new(0.0f, 0.0f);
    /// <summary>
    /// The vector (1, 0).
    /// </summary>
    public static readonly float2 UnitX = new(1.0f, 0.0f);
    /// <summary>
    /// The vector (0, 1).
    /// </summary>
    public static readonly float2 UnitY = new(0.0f, 1.0f);
    /// <summary>
    /// A vector whose elements are all equal to one.
    /// </summary>
    public static readonly float2 One = new(0.0f, 0.0f);

    public static explicit operator Vector2(float2 self) => new(self.X, self.Y);
    public static explicit operator float2(Vector2 self) => new(self.X, self.Y);
}

/// <summary>
/// Represents a vector with three single-precision floating-point values.
/// </summary>
[Vector(typeof(float), 3, "float")]
[ComparableVector]
[VectorMath]
[VectorCast(typeof(int3), true)]
[VectorCast(typeof(double3), true)]
[VectorCast(typeof(half3), true)]
public partial struct float3
{
    /// <summary>
    /// A vector whose elements are all equal to zero.
    /// </summary>
    public static readonly float3 Zero = new(0.0f, 0.0f, 0.0f);
    /// <summary>
    /// The vector (1, 0, 0).
    /// </summary>
    public static readonly float3 UnitX = new(1.0f, 0.0f, 0.0f);
    /// <summary>
    /// The vector (0, 1, 0).
    /// </summary>
    public static readonly float3 UnitY = new(0.0f, 1.0f, 0.0f);
    /// <summary>
    /// The vector (0, 0, 1).
    /// </summary>
    public static readonly float3 UnitZ = new(0.0f, 0.0f, 1.0f);
    /// <summary>
    /// A vector whose elements are all equal to one.
    /// </summary>
    public static readonly float3 One = new(0.0f, 0.0f, 0.0f);

    /// <summary>
    /// The vector (0, 0, 1).
    /// </summary>
    public static readonly float3 Forward = new(0.0f, 0.0f, 1.0f);
    /// <summary>
    /// The vector (0, 0, -1).
    /// </summary>
    public static readonly float3 Backward = new(0.0f, 0.0f, -1.0f);
    /// <summary>
    /// The vector (-1, 0, 0).
    /// </summary>
    public static readonly float3 Left = new(-1.0f, 0.0f, 0.0f);
    /// <summary>
    /// The vector (1, 0, 0).
    /// </summary>
    public static readonly float3 Right = new(1.0f, 0.0f, 0.0f);
    /// <summary>
    /// The vector (0, 1, 0).
    /// </summary>
    public static readonly float3 Up = new(0.0f, 1.0f, 0.0f);
    /// <summary>
    /// The vector (0, -1, 0).
    /// </summary>
    public static readonly float3 Down = new(0.0f, -1.0f, 0.0f);
    
    public static explicit operator Vector3(float3 self) => new(self.X, self.Y, self.Z);
    public static explicit operator float3(Vector3 self) => new(self.X, self.Y, self.Z);
}

/// <summary>
/// Represents a vector with four single-precision floating-point values.
/// </summary>
[Vector(typeof(float), 4, "float")]
[ComparableVector]
[VectorMath]
[VectorCast(typeof(int4), true)]
[VectorCast(typeof(double4), true)]
[VectorCast(typeof(half4), true)]
public partial struct float4
{
    /// <summary>
    /// A vector whose elements are all equal to zero.
    /// </summary>
    public static readonly float4 Zero	= new(0f, 0f, 0f, 0f);
    /// <summary>
    /// The vector (1, 0, 0, 0).
    /// </summary>
    public static readonly float4 UnitX	= new(1f, 0f, 0f, 0f);
    /// <summary>
    /// The vector (0, 1, 0, 0).
    /// </summary>
    public static readonly float4 UnitY	= new(0f, 1f, 0f, 0f);
    /// <summary>
    /// The vector (0, 0, 1, 0).
    /// </summary>
    public static readonly float4 UnitZ	= new(0f, 0f, 1f, 0f);
    /// <summary>
    /// The vector (0, 0, 0, 1).
    /// </summary>
    public static readonly float4 UnitW	= new(0f, 0f, 0f, 1f);
    /// <summary>
    /// A vector whose elements are all equal to one.
    /// </summary>
    public static readonly float4 One   = new(1f, 1f, 1f, 1f);

    public static explicit operator Vector4(float4 self) => new(self.X, self.Y, self.Z, self.W);
    public static explicit operator float4(Vector4 self) => new(self.X, self.Y, self.Z, self.W);
}
