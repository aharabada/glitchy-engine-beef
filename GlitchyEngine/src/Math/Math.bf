using System;

namespace GlitchyEngine.Math;

// TODO: Not all functions are available for scalars yet

static
{
	/// Returns true if at least one of the components is true.
	public static bool any(bool value) => value;
	/// Returns true if at least one of the components is true.
	public static bool any(bool2 value) => value.X || value.Y;
	/// Returns true if at least one of the components is true.
	public static bool any(bool3 value) => value.X || value.Y || value.Z;
	/// Returns true if at least one of the components is true.
	public static bool any(bool4 value) => value.X || value.Y || value.Z || value.W;
	
	/// Returns true if all of the components are true.
	public static bool all(bool value) => value;
	/// Returns true if all of the components are true.
	public static bool all(bool2 value) => value.X && value.Y;
	/// Returns true if all of the components are true.
	public static bool all(bool3 value) => value.X && value.Y && value.Z;
	/// Returns true if all of the components are true.
	public static bool all(bool4 value) => value.X && value.Y && value.Z && value.W;

#region abs
	
	public static float abs(float value)
	{
		return Math.Abs(value);
	}

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
	
	public static int abs(int value)
	{
		return Math.Abs(value);
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

#region Sign

	/// Returns the sign of x.
	public static int32 sign(float x)
	{
		return (int32)Math.Sign(x);
	}

	/// Returns the sign of x.
	public static int2 sign(float2 x)
	{
		return int2((int32)Math.Sign(x.X), (int32)Math.Sign(x.Y));
	}

	/// Returns the sign of x.
	public static int3 sign(float3 x)
	{
		return int3((int32)Math.Sign(x.X), (int32)Math.Sign(x.Y), (int32)Math.Sign(x.Z));
	}

	/// Returns the sign of x.
	public static int4 sign(float4 x)
	{
		return int4((int32)Math.Sign(x.X), (int32)Math.Sign(x.Y), (int32)Math.Sign(x.Z), (int32)Math.Sign(x.W));
	}

	/// Returns the sign of x.
	public static int32 sign(int x)
	{
		return (int32)Math.Sign(x);
	}

	/// Returns the sign of x.
	public static int2 sign(int2 x)
	{
		return int2((int32)Math.Sign(x.X), (int32)Math.Sign(x.Y));
	}

	/// Returns the sign of x.
	public static int3 sign(int3 x)
	{
		return int3((int32)Math.Sign(x.X), (int32)Math.Sign(x.Y), (int32)Math.Sign(x.Z));
	}

	/// Returns the sign of x.
	public static int4 sign(int4 x)
	{
		return int4((int32)Math.Sign(x.X), (int32)Math.Sign(x.Y), (int32)Math.Sign(x.Z), (int32)Math.Sign(x.W));
	}

#endregion

#region ceil / floor / round
	
	public static float ceil(float value)
	{
		return Math.Ceiling(value);
	}

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
	
	public static float floor(float value)
	{
		return Math.Floor(value);
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
	
	/// Rounds the specified value to the nearest integer.
	public static float round(float value)
	{
		return Math.Round(value);
	}

	/// Rounds the specified value to the nearest integer.
	public static float2 round(float2 value)
	{
		return float2(Math.Round(value.X), Math.Round(value.Y));
	}

	/// Rounds the specified value to the nearest integer.
	public static float3 round(float3 value)
	{
		return float3(Math.Round(value.X), Math.Round(value.Y), Math.Round(value.Z));
	}

	/// Rounds the specified value to the nearest integer.
	public static float4 round(float4 value)
	{
		return float4(Math.Round(value.X), Math.Round(value.Y), Math.Round(value.Z), Math.Round(value.W));
	}

#endregion
	
#region min / max
	
	public static float min(float x, float y)
	{
		return Math.Min(x, y);
	}

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
	
	public static float max(float x, float y)
	{
		return Math.Max(x, y);
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
	
#region exp, pow, log

	// TODO: log, log10, log2

	/// Returns x raised to the power of y.
	public static float pow(float x, float y)
	{
		return Math.Pow(x, y);
	}

	/// Returns x raised to the power of y.
	public static float2 pow(float2 x, float2 y)
	{
		return float2(Math.Pow(x.X, y.X), Math.Pow(x.Y, y.Y));
	}

	/// Returns x raised to the power of y.
	public static float3 pow(float3 x, float3 y)
	{
		return float3(Math.Pow(x.X, y.X), Math.Pow(x.Y, y.Y), Math.Pow(x.Z, y.Z));
	}

	/// Returns x raised to the power of y.
	public static float4 pow(float4 x, float4 y)
	{
		return float4(Math.Pow(x.X, y.X), Math.Pow(x.Y, y.Y), Math.Pow(x.Z, y.Z), Math.Pow(x.W, y.W));
	}

	/// Returns the base-e exponential, or e^x, of the specified value.
	public static float exp(float x)
	{
		return Math.Exp(x);
	}

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

	/// Returns the base 2 exponential, or 2^x, of the specified value.
	public static float exp2(float x)
	{
		return Math.Pow(2, x);
	}

	/// Returns the base 2 exponential, or 2^x, of the specified value.
	public static float2 exp2(float2 x)
	{
		return float2(Math.Pow(2, x.X), Math.Pow(2, x.Y));
	}

	/// Returns the base 2 exponential, or 2^x, of the specified value.
	public static float3 exp2(float3 x)
	{
		return float3(Math.Pow(2, x.X), Math.Pow(2, x.Y), Math.Pow(2, x.Z));
	}

	/// Returns the base 2 exponential, or 2^x, of the specified value.
	public static float4 exp2(float4 x)
	{
		return float4(Math.Pow(2, x.X), Math.Pow(2, x.Y), Math.Pow(2, x.Z), Math.Pow(2, x.W));
	}

#endregion
	
#region Degrees / Radians

	public static float toDegrees(float radians) => radians * MathHelper.RadToDeg;
	public static float2 toDegrees(float2 radians) => radians * MathHelper.RadToDeg;
	public static float3 toDegrees(float3 radians) => radians * MathHelper.RadToDeg;
	public static float4 toDegrees(float4 radians) => radians * MathHelper.RadToDeg;

	public static float toRadians(float degrees) => degrees * MathHelper.DegToRad;
	public static float2 toRadians(float2 degrees) => degrees * MathHelper.DegToRad;
	public static float3 toRadians(float3 degrees) => degrees * MathHelper.DegToRad;
	public static float4 toRadians(float4 degrees) => degrees * MathHelper.DegToRad;

#endregion

#region Clamp
	
	public static float clamp(float value, float min, float max)
	{
		return Math.Clamp(value.X, min.X, max.X);
	}

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
	public static float lerp(float x, float y, float s)
	{
		return x + s * (y - x);
	}

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

	// mul? hlsl has like 280 overloads...
	
	public static float normalize(float value) => 1.0f;
	public static float2 normalize(float2 value) => value / length(value);
	public static float3 normalize(float3 value) => value / length(value);
	public static float4 normalize(float4 value) => value / length(value);

	// pow

#region Reflect and Refract

	/// Returns a reflection vector using an incident ray and a surface normal.
	public static float2 reflect(float2 incident, float2 normal) => incident - 2 * normal * dot(incident, normal);
	/// Returns a reflection vector using an incident ray and a surface normal.
	public static float3 reflect(float3 incident, float3 normal) => incident - 2 * normal * dot(incident, normal);
	/// Returns a reflection vector using an incident ray and a surface normal.
	public static float4 reflect(float4 incident, float4 normal) => incident - 2 * normal * dot(incident, normal);

	// Source: https://thebookofshaders.com/glossary/?search=refract
	/// Returns a refraction vector using an entering ray, a surface normal, and a refraction index.
	public static float2 refract(float2 incident, float2 normal, float refractionIndex)
	{
		float dot_n_i = dot(normal, incident);

		float k = 1.0f - refractionIndex * refractionIndex * (1.0f - dot_n_i * dot_n_i);

		if (k < 0.0f)
			return 0.0f;
		else
			return refractionIndex * incident - (refractionIndex * dot_n_i + sqrt(k));
	}

	/// Returns a refraction vector using an entering ray, a surface normal, and a refraction index.
	public static float3 refract(float3 incident, float3 normal, float refractionIndex)
	{
		float dot_n_i = dot(normal, incident);

		float k = 1.0f - refractionIndex * refractionIndex * (1.0f - dot_n_i * dot_n_i);

		if (k < 0.0f)
			return 0.0f;
		else
			return refractionIndex * incident - (refractionIndex * dot_n_i + sqrt(k));
	}

	/// Returns a refraction vector using an entering ray, a surface normal, and a refraction index.
	public static float4 refract(float4 incident, float4 normal, float refractionIndex)
	{
		float dot_n_i = dot(normal, incident);

		float k = 1.0f - refractionIndex * refractionIndex * (1.0f - dot_n_i * dot_n_i);

		if (k < 0.0f)
			return 0.0f;
		else
			return refractionIndex * incident - (refractionIndex * dot_n_i + sqrt(k));
	}

#endregion

	/// Calculates the per component square root of the given value.
	public static float sqrt(float value)
	{
		return Math.Sqrt(value);
	}
	
	/// Calculates the per component square root of the given value.
	public static float2 sqrt(float2 value)
	{
		return float2(Math.Sqrt(value.X), Math.Sqrt(value.Y));
	}
	
	/// Calculates the per component square root of the given value.
	public static float3 sqrt(float3 value)
	{
		return float3(Math.Sqrt(value.X), Math.Sqrt(value.Y), Math.Sqrt(value.Z));
	}

	/// Calculates the per component square root of the given value.
	public static float4 sqrt(float4 value)
	{
		return float4(Math.Sqrt(value.X), Math.Sqrt(value.Y), Math.Sqrt(value.Z), Math.Sqrt(value.W));
	}

	// saturate (I don't think there is a faster way than simply using clamp, so simply use clamp...)

#region Step / Smoothstep

	/// Compares two values, returning 0 or 1 based on which value is greater.
	/// @returns 1 if the x parameter is greater than or equal to the y parameter; otherwise, 0.
	public static float step(float y, float x)
	{
		return (x >= y) ? 1.0f : 0.0f;
	}

	/// Compares two values, returning 0 or 1 based on which value is greater.
	/// @returns 1 if the x parameter is greater than or equal to the y parameter; otherwise, 0.
	public static float2 step(float2 y, float2 x)
	{
		bool2 b = (x >= y);

		return float2(b.X ? 1.0f : 0.0f, b.Y ? 1.0f : 0.0f);
	}

	/// Compares two values, returning 0 or 1 based on which value is greater.
	/// @returns 1 if the x parameter is greater than or equal to the y parameter; otherwise, 0.
	public static float3 step(float3 y, float3 x)
	{
		bool3 b = (x >= y);

		return float3(b.X ? 1.0f : 0.0f, b.Y ? 1.0f : 0.0f, b.Z ? 1.0f : 0.0f);
	}
	
	/// Compares two values, returning 0 or 1 based on which value is greater.
	/// @returns 1 if the x parameter is greater than or equal to the y parameter; otherwise, 0.
	public static float4 step(float4 y, float4 x)
	{
		bool4 b = (x >= y);

		return float4(b.X ? 1.0f : 0.0f, b.Y ? 1.0f : 0.0f, b.Z ? 1.0f : 0.0f, b.W ? 1.0f : 0.0f);
	}

	// Source: https://thebookofshaders.com/glossary/?search=smoothstep

	/// Returns a smooth Hermite interpolation between 0 and 1, if x is in the range [min, max].
	/// @returns Returns 0 if x is less than min; 1 if x is greater than max; otherwise, a value between 0 and 1 if x is in the range [min, max].
	public static float smoothstep(float min, float max, float x)
	{
		float t = clamp((x - min) / (max - min), 0.0f, 1.0f);
		return t * t * (3.0f - 2.0f * t);
	}

	/// Returns a smooth Hermite interpolation between 0 and 1, if x is in the range [min, max].
	/// @returns Returns 0 if x is less than min; 1 if x is greater than max; otherwise, a value between 0 and 1 if x is in the range [min, max].
	public static float2 smoothstep(float2 min, float2 max, float2 x)
	{
		float2 t = clamp((x - min) / (max - min), 0.0f, 1.0f);
		return t * t * (3.0f - 2.0f * t);
	}

	/// Returns a smooth Hermite interpolation between 0 and 1, if x is in the range [min, max].
	/// @returns Returns 0 if x is less than min; 1 if x is greater than max; otherwise, a value between 0 and 1 if x is in the range [min, max].
	public static float3 smoothstep(float3 min, float3 max, float3 x)
	{
		float3 t = clamp((x - min) / (max - min), 0.0f, 1.0f);
		return t * t * (3.0f - 2.0f * t);
	}

	/// Returns a smooth Hermite interpolation between 0 and 1, if x is in the range [min, max].
	/// @returns Returns 0 if x is less than min; 1 if x is greater than max; otherwise, a value between 0 and 1 if x is in the range [min, max].
	public static float4 smoothstep(float4 min, float4 max, float4 x)
	{
		float4 t = clamp((x - min) / (max - min), 0.0f, 1.0f);
		return t * t * (3.0f - 2.0f * t);
	}

#endregion

#region Reject / Project

	/**
	 * Calculates the projection of a onto b
	 */
	public static float2 project(float2 a, float2 b)
	{
		return (b * (dot(a, b) / dot(b, b)));
	}

	/**
	 * Calculates the projection of a onto b
	 */
	public static float3 project(float3 a, float3 b)
	{
		return (b * (dot(a, b) / dot(b, b)));
	}

	/**
	 * Calculates the projection of a onto b
	 */
	public static float4 project(float4 a, float4 b)
	{
		return (b * (dot(a, b) / dot(b, b)));
	}

	/**
	 * Calculates the rejection of a from b
	 */
	public static float2 reject(float2 a, float2 b)
	{
		return (a - b * (dot(a, b) / dot(b, b)));
	}
	
	/**
	 * Calculates the rejection of a from b
	 */
	public static float3 reject(float3 a, float3 b)
	{
		return (a - b * (dot(a, b) / dot(b, b)));
	}
	
	/**
	 * Calculates the rejection of a from b
	 */
	public static float4 reject(float4 a, float4 b)
	{
		return (a - b * (dot(a, b) / dot(b, b)));
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

	// transpose und determinante für Matrizen

	// sin, cos, tan, asin, acos, atan, atan2, cosh, sinh, tanh
}