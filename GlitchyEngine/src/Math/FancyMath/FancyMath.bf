using System;
namespace GlitchyEngine.Math.FancyMath;

static class FancyMath
{
	/// Returns true if at least one of the components is true.
	public static bool any(bool2 value) => value.X || value.Y;
	/// Returns true if at least one of the components is true.
	public static bool any(bool3 value) => value.X || value.Y || value.Z;
	/// Returns true if at least one of the components is true.
	public static bool any(bool4 value) => value.X || value.Y || value.Z || value.W;
	
	/// Returns true if all of the components are true.
	public static bool all(bool2 value) => value.X && value.Y;
	/// Returns true if all of the components are true.
	public static bool all(bool3 value) => value.X && value.Y && value.Z;
	/// Returns true if all of the components are true.
	public static bool all(bool4 value) => value.X && value.Y && value.Z && value.W;

#region abs
	
	public static float2 abs(float2 value)
	{
		return float2(Math.Abs(value.X), Math.Abs(value.Y));
	}

	public static float3 abs(float3 value)
	{
		return float3(Math.Abs(value.X), Math.Abs(value.Y), Math.Abs(value.Z));
	}
	
	public static float4 abs(float4 value)
	{
		return float4(Math.Abs(value.X), Math.Abs(value.Y), Math.Abs(value.Z), Math.Abs(value.W));
	}
	
	public static int2 abs(int2 value)
	{
		return int2(Math.Abs(value.X), Math.Abs(value.Y));
	}

	public static int3 abs(int3 value)
	{
		return int3(Math.Abs(value.X), Math.Abs(value.Y), Math.Abs(value.Z));
	}

	public static int4 abs(int4 value)
	{
		return int4(Math.Abs(value.X), Math.Abs(value.Y), Math.Abs(value.Z), Math.Abs(value.W));
	}

#endregion

#region ceil / floor
	
	public static float2 ceil(float2 value)
	{
		return float2(Math.Ceiling(value.X), Math.Ceiling(value.Y));
	}

	public static float3 ceil(float3 value)
	{
		return float3(Math.Ceiling(value.X), Math.Ceiling(value.Y), Math.Ceiling(value.Z));
	}
	
	public static float4 ceil(float4 value)
	{
		return float4(Math.Ceiling(value.X), Math.Ceiling(value.Y), Math.Ceiling(value.Z), Math.Ceiling(value.W));
	}

	public static float2 floor(float2 value)
	{
		return float2(Math.Floor(value.X), Math.Floor(value.Y));
	}

	public static float3 floor(float3 value)
	{
		return float3(Math.Floor(value.X), Math.Floor(value.Y), Math.Floor(value.Z));
	}
	
	public static float4 floor(float4 value)
	{
		return float4(Math.Floor(value.X), Math.Floor(value.Y), Math.Floor(value.Z), Math.Floor(value.W));
	}

#endregion

#region Clamp
	
	public static float2 clamp(float2 value, float2 min, float2 max)
	{
		return float2(Math.Clamp(value.X, min.X, max.X), Math.Clamp(value.Y, min.Y, max.Y));
	}

	public static float3 clamp(float3 value, float3 min, float3 max)
	{
		return float3(Math.Clamp(value.X, min.X, max.X), Math.Clamp(value.Y, min.Y, max.Y), Math.Clamp(value.Z, min.Z, max.Z));
	}

	public static float4 clamp(float4 value, float4 min, float4 max)
	{
		return float4(Math.Clamp(value.X, min.X, max.X), Math.Clamp(value.Y, min.Y, max.Y), Math.Clamp(value.Z, min.Z, max.Z), Math.Clamp(value.W, min.W, max.W));
	}
	
	public static int2 clamp(int2 value, int2 min, int2 max)
	{
		return int2(Math.Clamp(value.X, min.X, max.X), Math.Clamp(value.Y, min.Y, max.Y));
	}

	public static int3 clamp(int3 value, int3 min, int3 max)
	{
		return int3(Math.Clamp(value.X, min.X, max.X), Math.Clamp(value.Y, min.Y, max.Y), Math.Clamp(value.Z, min.Z, max.Z));
	}

	public static int4 clamp(int4 value, int4 min, int4 max)
	{
		return int4(Math.Clamp(value.X, min.X, max.X), Math.Clamp(value.Y, min.Y, max.Y), Math.Clamp(value.Z, min.Z, max.Z), Math.Clamp(value.W, min.W, max.W));
	}

#endregion

#region Lerp

	/// Performs a linear interpolation.
	// @param x The first vector value.
	// @param y The second vector value.
	// @param y A value that linearly interpolates between x and y.
	public static float2 lerp(float2 x, float2 y, float s)
	{
		return x + s * (y - x);
	}

	/// Performs a linear interpolation.
	// @param x The first vector value.
	// @param y The second vector value.
	// @param y A value that linearly interpolates between x and y.
	public static float3 lerp(float3 x, float3 y, float s)
	{
		return x + s * (y - x);
	}

	/// Performs a linear interpolation.
	// @param x The first vector value.
	// @param y The second vector value.
	// @param y A value that linearly interpolates between x and y.
	public static float4 lerp(float4 x, float4 y, float s)
	{
		return x + s * (y - x);
	}

#endregion

	// log, log10, log2

#region min / max

	public static float2 min(float2 x, float2 y)
	{
		return float2(Math.Min(x.X, y.X), Math.Min(x.Y, y.Y));
	}

	public static float3 min(float3 x, float3 y)
	{
		return float3(Math.Min(x.X, y.X), Math.Min(x.Y, y.Y), Math.Min(x.Z, y.Z));
	}

	public static float4 min(float4 x, float4 y)
	{
		return float4(Math.Min(x.X, y.X), Math.Min(x.Y, y.Y), Math.Min(x.Z, y.Z), Math.Min(x.W, y.W));
	}

	public static float2 max(float2 x, float2 y)
	{
		return float2(Math.Max(x.X, y.X), Math.Max(x.Y, y.Y));
	}

	public static float3 max(float3 x, float3 y)
	{
		return float3(Math.Max(x.X, y.X), Math.Max(x.Y, y.Y), Math.Max(x.Z, y.Z));
	}

	public static float4 max(float4 x, float4 y)
	{
		return float4(Math.Max(x.X, y.X), Math.Max(x.Y, y.Y), Math.Max(x.Z, y.Z), Math.Max(x.W, y.W));
	}

#endregion

	// mul

	// normalize

	// pow

	// rcp??? (reciprocal)

	// reflect and refract?

	// round

	// rsqrt?

	// sqrt

	// saturate

	// sign

	// step and smoothstep

	// transpose

#region exp

	/// Returns the base-e exponential, or e^x, of the specified value.
	public static float2 exp(float2 x)
	{
		return float2(Math.Exp(x.X), Math.Exp(x.Y));
	}

	/// Returns the base-e exponential, or e^x, of the specified value.
	public static float3 exp(float3 x)
	{
		return float3(Math.Exp(x.X), Math.Exp(x.Y), Math.Exp(x.Z));
	}

	/// Returns the base-e exponential, or e^x, of the specified value.
	public static float4 exp(float4 x)
	{
		return float4(Math.Exp(x.X), Math.Exp(x.Y), Math.Exp(x.Z), Math.Exp(x.W));
	}

	// Exp2?

#endregion

#region modf / frac / trunc
	
	// Splits the value x into fractional and integer parts, each of which has the same sign as x.
	public static float2 modf(float2 x, out float2 integerPart)
	{
		float2 fracPart;

		fracPart.X = Math.[Friend]modff(x.X, out integerPart.X);
		fracPart.Y = Math.[Friend]modff(x.Y, out integerPart.Y);

		return fracPart;
	}
	
	// Splits the value x into fractional and integer parts, each of which has the same sign as x.
	public static float3 modf(float3 x, out float3 integerPart)
	{
		float3 fracPart;

		fracPart.X = Math.[Friend]modff(x.X, out integerPart.X);
		fracPart.Y = Math.[Friend]modff(x.Y, out integerPart.Y);
		fracPart.Z = Math.[Friend]modff(x.Z, out integerPart.Z);

		return fracPart;
	}
	
	// Splits the value x into fractional and integer parts, each of which has the same sign as x.
	public static float4 modf(float4 x, out float4 integerPart)
	{
		float4 fracPart;

		fracPart.X = Math.[Friend]modff(x.X, out integerPart.X);
		fracPart.Y = Math.[Friend]modff(x.Y, out integerPart.Y);
		fracPart.Z = Math.[Friend]modff(x.Z, out integerPart.Z);
		fracPart.W = Math.[Friend]modff(x.W, out integerPart.W);

		return fracPart;
	}


	// Returns the fractional (or decimal) part of x; which is greater than or equal to 0 and less than 1.
	public static float2 frac(float2 x) => [Inline]modf(x, let _);

	// Returns the fractional (or decimal) part of x; which is greater than or equal to 0 and less than 1.
	public static float3 frac(float3 x) => [Inline]modf(x, let _);

	// Returns the fractional (or decimal) part of x; which is greater than or equal to 0 and less than 1.
	public static float4 frac(float4 x) => [Inline]modf(x, let _);


	// Truncates a floating-point value to the integer component.
	public static float2 trunc(float2 x)
	{
		return float2(Math.Truncate(x.X), Math.Truncate(x.Y));
	}

	// Truncates a floating-point value to the integer component.
	public static float3 trunc(float3 x)
	{
		return float3(Math.Truncate(x.X), Math.Truncate(x.Y), Math.Truncate(x.Z));
	}

	// Truncates a floating-point value to the integer component.
	public static float4 trunc(float4 x)
	{
		return float4(Math.Truncate(x.X), Math.Truncate(x.Y), Math.Truncate(x.Z), Math.Truncate(x.W));
	}

#endregion

#region infinity and nan check

	/// Determines if the specified floating-point value is finite.
	public static bool2 isfinite(float2 value)
	{
		return bool2(value.X.IsFinite, value.Y.IsFinite);
	}

	/// Determines if the specified floating-point value is finite.
	public static bool3 isfinite(float3 value)
	{
		return bool3(value.X.IsFinite, value.Y.IsFinite, value.Z.IsFinite);
	}

	/// Determines if the specified floating-point value is finite.
	public static bool4 isfinite(float4 value)
	{
		return bool4(value.X.IsFinite, value.Y.IsFinite, value.Z.IsFinite, value.W.IsFinite);
	}

	/// Determines if the specified value is infinite.
	public static bool2 isinf(float2 value)
	{
		return bool2(value.X.IsInfinity, value.Y.IsInfinity);
	}
	
	/// Determines if the specified value is infinite.
	public static bool3 isinf(float3 value)
	{
		return bool3(value.X.IsInfinity, value.Y.IsInfinity, value.Z.IsInfinity);
	}
	
	/// Determines if the specified value is infinite.
	public static bool4 isinf(float4 value)
	{
		return bool4(value.X.IsInfinity, value.Y.IsInfinity, value.Z.IsInfinity, value.W.IsInfinity);
	}
	
	/// Determines if the specified value is infinite.
	public static bool2 isnan(float2 value)
	{
		return bool2(value.X.IsNaN, value.Y.IsNaN);
	}

	/// Determines if the specified value is infinite.
	public static bool3 isnan(float3 value)
	{
		return bool3(value.X.IsNaN, value.Y.IsNaN, value.Z.IsNaN);
	}

	/// Determines if the specified value is infinite.
	public static bool4 isnan(float4 value)
	{
		return bool4(value.X.IsNaN, value.Y.IsNaN, value.Z.IsNaN, value.W.IsNaN);
	}

#endregion


#region dot

	public static float dot(float2 left, float2 right)
	{
		return left.X * right.X + left.Y * right.Y;
	}
	
	public static float dot(float3 left, float3 right)
	{
		return left.X * right.X + left.Y * right.Y + left.Z * right.Z;
	}

	public static float dot(float4 left, float4 right)
	{
		return left.X * right.X + left.Y * right.Y + left.Z * right.Z + left.W * right.W;
	}

	public static int dot(int2 left, int2 right)
	{
		return left.X * right.X + left.Y * right.Y;
	}
	
	public static int dot(int3 left, int3 right)
	{
		return left.X * right.X + left.Y * right.Y + left.Z * right.Z;
	}

	public static int dot(int4 left, int4 right)
	{
		return left.X * right.X + left.Y * right.Y + left.Z * right.Z + left.W * right.W;
	}

#endregion

#region lengthSq / length / DistanceSq / Distance
	
	public static float lengthSq(float2 value) => dot(value, value);

	public static float lengthSq(float3 value) => dot(value, value);

	public static float lengthSq(float4 value) => dot(value, value);

	public static int lengthSq(int2 value) => dot(value, value);

	public static int lengthSq(int3 value) => dot(value, value);

	public static int lengthSq(int4 value) => dot(value, value);

	public static float length(float2 value) => Math.Sqrt(lengthSq(value));
	
	public static float length(float3 value) => Math.Sqrt(lengthSq(value));

	public static float length(float4 value) => Math.Sqrt(lengthSq(value));



	public static float distanceSq(float2 left, float2 right) => dot(left, right);
	
	public static float distanceSq(float3 left, float3 right) => dot(left, right);
	
	public static float distanceSq(float4 left, float4 right) => dot(left, right);
	
	public static float distance(float2 left, float2 right) => Math.Sqrt(distanceSq(left, right));

	public static float distance(float3 left, float3 right) => Math.Sqrt(distanceSq(left, right));

	public static float distance(float4 left, float4 right) => Math.Sqrt(distanceSq(left, right));

#endregion

	public static float3 cross(float3 left, float3 right)
	{
		return float3(
			left.Y * right.Z - left.Z * right.Y,
		 	left.Z * right.X - left.X * right.Z,
		 	left.X * right.Y - left.Y * right.X);
	}

#region Degrees / Radians
	
	public static float2 toDegrees(float2 radians) => radians * MathHelper.RadToDeg;
	public static float3 toDegrees(float3 radians) => radians * MathHelper.RadToDeg;
	public static float4 toDegrees(float4 radians) => radians * MathHelper.RadToDeg;
	
	public static float2 toRadians(float2 degrees) => degrees * MathHelper.DegToRad;
	public static float3 toRadians(float3 degrees) => degrees * MathHelper.DegToRad;
	public static float4 toRadians(float4 degrees) => degrees * MathHelper.DegToRad;

#endregion

	// transpose und determinante für Matrizen

	// sin, cos, tan, asin, acos, atan, atan2, cosh, sinh, tanh

}