// ReSharper disable InconsistentNaming
#pragma warning disable IDE1006

using System;
using System.Runtime.CompilerServices;

namespace GlitchyEngine.Math;

/// <summary>
/// Provides constants and methods for trigonometric and vector calculations.
/// </summary>
public static class Math
{
    /// An optimal representation of π.
    public const float Pi = 3.141592654f;

    /// An optimal representation of 2*π.
    public const float TwoPi = 6.283185307f;

    /// An optimal representation of 1/π.
    public const float OneOverPi = 0.318309886f;

    /// An optimal representation of 2/π.
    public const float OneOverTwoPi = 0.159154943f;

    /// An optimal representation of π/2.
    public const float PiOverTwo = 1.570796327f;

    /// An optimal representation of π/4.
    public const float PiOverFour = 0.785398163f;

    /// Converts radians to degrees
    public const float RadToDeg = 180.0f / Pi;

    /// Converts radians to degrees
    public const float DegToRad = Pi / 180.0f;


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
        return System.Math.Abs(value);
    }

    public static float2 abs(float2 value)
    {
        return new float2(System.Math.Abs(value.X), System.Math.Abs(value.Y));
    }

    public static float3 abs(float3 value)
    {
        return new float3(System.Math.Abs(value.X), System.Math.Abs(value.Y), System.Math.Abs(value.Z));
    }

    public static float4 abs(float4 value)
    {
        return new float4(System.Math.Abs(value.X), System.Math.Abs(value.Y), System.Math.Abs(value.Z),
            System.Math.Abs(value.W));
    }

    public static int abs(int value)
    {
        return System.Math.Abs(value);
    }

    public static int2 abs(int2 value)
    {
        return new int2(System.Math.Abs(value.X), System.Math.Abs(value.Y));
    }

    public static int3 abs(int3 value)
    {
        return new int3(System.Math.Abs(value.X), System.Math.Abs(value.Y), System.Math.Abs(value.Z));
    }

    public static int4 abs(int4 value)
    {
        return new int4(System.Math.Abs(value.X), System.Math.Abs(value.Y), System.Math.Abs(value.Z),
            System.Math.Abs(value.W));
    }

    #endregion

    #region modf / frac / trunc

    /// <summary>
    /// Splits the value x into fractional and integer parts, each of which has the same sign as x.
    /// </summary>
    public static float modf(float x, out float integerPart) => ScriptGlue.modf_float(x, out integerPart);

    /// <inheritdoc cref="modf(float,out float)"/>
    public static float2 modf(float2 x, out float2 integerPart) => ScriptGlue.modf_float2(x, out integerPart);

    /// <inheritdoc cref="modf(float2,out float2)"/>
    public static float3 modf(float3 x, out float3 integerPart) => ScriptGlue.modf_float3(x, out integerPart);

    /// <inheritdoc cref="modf(float2,out float2)"/>
    public static float4 modf(float4 x, out float4 integerPart) => ScriptGlue.modf_float4(x, out integerPart);

    /// <summary>
    /// Returns the fractional (or decimal) part of x; which is greater than or equal to 0 and less than 1.
    /// </summary>
    public static float frac(float x) => modf(x, out _);

    /// <inheritdoc cref="frac(float)"/>
    public static float2 frac(float2 x) => modf(x, out _);

    /// <inheritdoc cref="frac(float)"/>
    public static float3 frac(float3 x) => modf(x, out _);

    /// <inheritdoc cref="frac(float)"/>
    public static float4 frac(float4 x) => modf(x, out _);


    /// <summary>
    /// Truncates a floating-point value to the integer component.
    /// </summary>
    public static float trunc(float x)
    {
        return (float)System.Math.Truncate(x);
    }

    /// <summary>
    /// Truncates a floating-point value to the integer component.
    /// </summary>
    public static float2 trunc(float2 x)
    {
        return new float2((float)System.Math.Truncate(x.X), (float)System.Math.Truncate(x.Y));
    }

    /// <summary>
    /// Truncates a floating-point value to the integer component.
    /// </summary>
    public static float3 trunc(float3 x)
    {
        return new float3((float)System.Math.Truncate(x.X), (float)System.Math.Truncate(x.Y),
            (float)System.Math.Truncate(x.Z));
    }

    /// <summary>
    /// Truncates a floating-point value to the integer component.
    /// </summary>
    public static float4 trunc(float4 x)
    {
        return new float4((float)System.Math.Truncate(x.X), (float)System.Math.Truncate(x.Y),
            (float)System.Math.Truncate(x.Z), (float)System.Math.Truncate(x.W));
    }

    #endregion

    #region infinity and nan check

    /// Determines if the specified floating-point value is finite.
    public static bool2 isfinite(float2 value)
    {
        return new bool2(!float.IsInfinity(value.X), !float.IsInfinity(value.Y));
    }

    /// Determines if the specified floating-point value is finite.
    public static bool3 isfinite(float3 value)
    {
        return new bool3(!float.IsInfinity(value.X), !float.IsInfinity(value.Y), !float.IsInfinity(value.Z));
    }

    /// Determines if the specified floating-point value is finite.
    public static bool4 isfinite(float4 value)
    {
        return new bool4(!float.IsInfinity(value.X), !float.IsInfinity(value.Y), !float.IsInfinity(value.Z),
            !float.IsInfinity(value.W));
    }

    /// Determines if the specified value is infinite.
    public static bool2 isinf(float2 value)
    {
        return new bool2(float.IsInfinity(value.X), float.IsInfinity(value.Y));
    }

    /// Determines if the specified value is infinite.
    public static bool3 isinf(float3 value)
    {
        return new bool3(float.IsInfinity(value.X), float.IsInfinity(value.Y), float.IsInfinity(value.Z));
    }

    /// Determines if the specified value is infinite.
    public static bool4 isinf(float4 value)
    {
        return new bool4(float.IsInfinity(value.X), float.IsInfinity(value.Y), float.IsInfinity(value.Z),
            float.IsInfinity(value.W));
    }

    /// Determines if the specified value is infinite.
    public static bool2 isnan(float2 value)
    {
        return new bool2(float.IsNaN(value.X), float.IsNaN(value.Y));
    }

    /// Determines if the specified value is infinite.
    public static bool3 isnan(float3 value)
    {
        return new bool3(float.IsNaN(value.X), float.IsNaN(value.Y), float.IsNaN(value.Z));
    }

    /// Determines if the specified value is infinite.
    public static bool4 isnan(float4 value)
    {
        return new bool4(float.IsNaN(value.X), float.IsNaN(value.Y), float.IsNaN(value.Z), float.IsNaN(value.W));
    }

    #endregion

    #region Sign

    /// Returns the sign of x.
    public static int sign(float x)
    {
        return System.Math.Sign(x);
    }

    /// Returns the sign of x.
    public static int2 sign(float2 x)
    {
        return new int2(System.Math.Sign(x.X), System.Math.Sign(x.Y));
    }

    /// Returns the sign of x.
    public static int3 sign(float3 x)
    {
        return new int3(System.Math.Sign(x.X), System.Math.Sign(x.Y), System.Math.Sign(x.Z));
    }

    /// Returns the sign of x.
    public static int4 sign(float4 x)
    {
        return new int4(System.Math.Sign(x.X), System.Math.Sign(x.Y), System.Math.Sign(x.Z), System.Math.Sign(x.W));
    }

    /// Returns the sign of x.
    public static int sign(int x)
    {
        return System.Math.Sign(x);
    }

    /// Returns the sign of x.
    public static int2 sign(int2 x)
    {
        return new int2(System.Math.Sign(x.X), System.Math.Sign(x.Y));
    }

    /// Returns the sign of x.
    public static int3 sign(int3 x)
    {
        return new int3(System.Math.Sign(x.X), System.Math.Sign(x.Y), System.Math.Sign(x.Z));
    }

    /// Returns the sign of x.
    public static int4 sign(int4 x)
    {
        return new int4(System.Math.Sign(x.X), System.Math.Sign(x.Y), System.Math.Sign(x.Z), System.Math.Sign(x.W));
    }

    #endregion

    #region ceil / floor / round

    public static float ceil(float value)
    {
        return (float)System.Math.Ceiling(value);
    }

    public static float2 ceil(float2 value)
    {
        return new float2((float)System.Math.Ceiling(value.X), (float)System.Math.Ceiling(value.Y));
    }

    public static float3 ceil(float3 value)
    {
        return new float3((float)System.Math.Ceiling(value.X), (float)System.Math.Ceiling(value.Y),
            (float)System.Math.Ceiling(value.Z));
    }

    public static float4 ceil(float4 value)
    {
        return new float4((float)System.Math.Ceiling(value.X), (float)System.Math.Ceiling(value.Y),
            (float)System.Math.Ceiling(value.Z), (float)System.Math.Ceiling(value.W));
    }

    public static float floor(float value)
    {
        return (float)System.Math.Floor(value);
    }

    public static float2 floor(float2 value)
    {
        return new float2((float)System.Math.Floor(value.X), (float)System.Math.Floor(value.Y));
    }

    public static float3 floor(float3 value)
    {
        return new float3((float)System.Math.Floor(value.X), (float)System.Math.Floor(value.Y),
            (float)System.Math.Floor(value.Z));
    }

    public static float4 floor(float4 value)
    {
        return new float4((float)System.Math.Floor(value.X), (float)System.Math.Floor(value.Y),
            (float)System.Math.Floor(value.Z), (float)System.Math.Floor(value.W));
    }

    /// Rounds the specified value to the nearest integer.
    public static float round(float value)
    {
        return (float)System.Math.Round(value);
    }

    /// Rounds the specified value to the nearest integer.
    public static float2 round(float2 value)
    {
        return new float2((float)System.Math.Round(value.X), (float)System.Math.Round(value.Y));
    }

    /// Rounds the specified value to the nearest integer.
    public static float3 round(float3 value)
    {
        return new float3((float)System.Math.Round(value.X), (float)System.Math.Round(value.Y),
            (float)System.Math.Round(value.Z));
    }

    /// Rounds the specified value to the nearest integer.
    public static float4 round(float4 value)
    {
        return new float4((float)System.Math.Round(value.X), (float)System.Math.Round(value.Y),
            (float)System.Math.Round(value.Z), (float)System.Math.Round(value.W));
    }

    #endregion

    #region min / max

    public static float min(float x, float y)
    {
        return (float)System.Math.Min(x, y);
    }

    public static float2 min(float2 x, float2 y)
    {
        return new float2((float)System.Math.Min(x.X, y.X), (float)System.Math.Min(x.Y, y.Y));
    }

    public static float3 min(float3 x, float3 y)
    {
        return new float3((float)System.Math.Min(x.X, y.X), (float)System.Math.Min(x.Y, y.Y),
            (float)System.Math.Min(x.Z, y.Z));
    }

    public static float4 min(float4 x, float4 y)
    {
        return new float4((float)System.Math.Min(x.X, y.X), (float)System.Math.Min(x.Y, y.Y),
            (float)System.Math.Min(x.Z, y.Z), (float)System.Math.Min(x.W, y.W));
    }

    public static float max(float x, float y)
    {
        return (float)System.Math.Max(x, y);
    }

    public static float2 max(float2 x, float2 y)
    {
        return new float2((float)System.Math.Max(x.X, y.X), (float)System.Math.Max(x.Y, y.Y));
    }

    public static float3 max(float3 x, float3 y)
    {
        return new float3((float)System.Math.Max(x.X, y.X), (float)System.Math.Max(x.Y, y.Y),
            (float)System.Math.Max(x.Z, y.Z));
    }

    public static float4 max(float4 x, float4 y)
    {
        return new float4((float)System.Math.Max(x.X, y.X), (float)System.Math.Max(x.Y, y.Y),
            (float)System.Math.Max(x.Z, y.Z), (float)System.Math.Max(x.W, y.W));
    }

    #endregion

    #region exp, pow, log

    // TODO: log, log10, log2

    // Returns x raised to the power of y.
    public static float pow(float x, float y)
    {
        return (float)System.Math.Pow(x, y);
    }

    /// Returns x raised to the power of y.
    public static float2 pow(float2 x, float2 y)
    {
        return new float2((float)System.Math.Pow(x.X, y.X), (float)System.Math.Pow(x.Y, y.Y));
    }

    /// Returns x raised to the power of y.
    public static float3 pow(float3 x, float3 y)
    {
        return new float3((float)System.Math.Pow(x.X, y.X), (float)System.Math.Pow(x.Y, y.Y),
            (float)System.Math.Pow(x.Z, y.Z));
    }

    /// Returns x raised to the power of y.
    public static float4 pow(float4 x, float4 y)
    {
        return new float4((float)System.Math.Pow(x.X, y.X), (float)System.Math.Pow(x.Y, y.Y),
            (float)System.Math.Pow(x.Z, y.Z), (float)System.Math.Pow(x.W, y.W));
    }

    /// Returns the base-e exponential, or e^x, of the specified value.
    public static float exp(float x)
    {
        return (float)System.Math.Exp(x);
    }

    /// Returns the base-e exponential, or e^x, of the specified value.
    public static float2 exp(float2 x)
    {
        return new float2((float)System.Math.Exp(x.X), (float)System.Math.Exp(x.Y));
    }

    /// Returns the base-e exponential, or e^x, of the specified value.
    public static float3 exp(float3 x)
    {
        return new float3((float)System.Math.Exp(x.X), (float)System.Math.Exp(x.Y), (float)System.Math.Exp(x.Z));
    }

    /// Returns the base-e exponential, or e^x, of the specified value.
    public static float4 exp(float4 x)
    {
        return new float4((float)System.Math.Exp(x.X), (float)System.Math.Exp(x.Y), (float)System.Math.Exp(x.Z),
            (float)System.Math.Exp(x.W));
    }

    /// Returns the base 2 exponential, or 2^x, of the specified value.
    public static float exp2(float x)
    {
        return (float)System.Math.Pow(2, x);
    }

    /// Returns the base 2 exponential, or 2^x, of the specified value.
    public static float2 exp2(float2 x)
    {
        return new float2((float)System.Math.Pow(2, x.X), (float)System.Math.Pow(2, x.Y));
    }

    /// Returns the base 2 exponential, or 2^x, of the specified value.
    public static float3 exp2(float3 x)
    {
        return new float3((float)System.Math.Pow(2, x.X), (float)System.Math.Pow(2, x.Y),
            (float)System.Math.Pow(2, x.Z));
    }

    /// Returns the base 2 exponential, or 2^x, of the specified value.
    public static float4 exp2(float4 x)
    {
        return new float4((float)System.Math.Pow(2, x.X), (float)System.Math.Pow(2, x.Y),
            (float)System.Math.Pow(2, x.Z), (float)System.Math.Pow(2, x.W));
    }

    #endregion

    #region Degrees / Radians

    public static float toDegrees(float radians) => radians * RadToDeg;
    public static float2 toDegrees(float2 radians) => radians * RadToDeg;
    public static float3 toDegrees(float3 radians) => radians * RadToDeg;
    public static float4 toDegrees(float4 radians) => radians * RadToDeg;

    public static float toRadians(float degrees) => degrees * DegToRad;
    public static float2 toRadians(float2 degrees) => degrees * DegToRad;
    public static float3 toRadians(float3 degrees) => degrees * DegToRad;
    public static float4 toRadians(float4 degrees) => degrees * DegToRad;

    #endregion

    #region Clamp

    public static float clamp(float value, float min, float max)
    {
        return value < min ? min : (value > max ? max : value);
    }

    public static float2 clamp(float2 value, float2 min, float2 max)
    {
        return new float2(clamp(value.X, min.X, max.X), clamp(value.Y, min.Y, max.Y));
    }

    public static float3 clamp(float3 value, float3 min, float3 max)
    {
        return new float3(clamp(value.X, min.X, max.X), clamp(value.Y, min.Y, max.Y), clamp(value.Z, min.Z, max.Z));
    }

    public static float4 clamp(float4 value, float4 min, float4 max)
    {
        return new float4(clamp(value.X, min.X, max.X), clamp(value.Y, min.Y, max.Y), clamp(value.Z, min.Z, max.Z),
            clamp(value.W, min.W, max.W));
    }

    public static int clamp(int value, int min, int max)
    {
        return value < min ? min : (value > max ? max : value);
    }

    public static int2 clamp(int2 value, int2 min, int2 max)
    {
        return new int2(clamp(value.X, min.X, max.X), clamp(value.Y, min.Y, max.Y));
    }

    public static int3 clamp(int3 value, int3 min, int3 max)
    {
        return new int3(clamp(value.X, min.X, max.X), clamp(value.Y, min.Y, max.Y), clamp(value.Z, min.Z, max.Z));
    }

    public static int4 clamp(int4 value, int4 min, int4 max)
    {
        return new int4(clamp(value.X, min.X, max.X), clamp(value.Y, min.Y, max.Y), clamp(value.Z, min.Z, max.Z),
            clamp(value.W, min.W, max.W));
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
        return (float)System.Math.Sqrt(value);
    }

    /// Calculates the per component square root of the given value.
    public static float2 sqrt(float2 value)
    {
        return new float2((float)System.Math.Sqrt(value.X), (float)System.Math.Sqrt(value.Y));
    }

    /// Calculates the per component square root of the given value.
    public static float3 sqrt(float3 value)
    {
        return new float3((float)System.Math.Sqrt(value.X), (float)System.Math.Sqrt(value.Y),
            (float)System.Math.Sqrt(value.Z));
    }

    /// Calculates the per component square root of the given value.
    public static float4 sqrt(float4 value)
    {
        return new float4((float)System.Math.Sqrt(value.X), (float)System.Math.Sqrt(value.Y),
            (float)System.Math.Sqrt(value.Z), (float)System.Math.Sqrt(value.W));
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

        return new float2(b.X ? 1.0f : 0.0f, b.Y ? 1.0f : 0.0f);
    }

    /// Compares two values, returning 0 or 1 based on which value is greater.
    /// @returns 1 if the x parameter is greater than or equal to the y parameter; otherwise, 0.
    public static float3 step(float3 y, float3 x)
    {
        bool3 b = (x >= y);

        return new float3(b.X ? 1.0f : 0.0f, b.Y ? 1.0f : 0.0f, b.Z ? 1.0f : 0.0f);
    }

    /// Compares two values, returning 0 or 1 based on which value is greater.
    /// @returns 1 if the x parameter is greater than or equal to the y parameter; otherwise, 0.
    public static float4 step(float4 y, float4 x)
    {
        bool4 b = (x >= y);

        return new float4(b.X ? 1.0f : 0.0f, b.Y ? 1.0f : 0.0f, b.Z ? 1.0f : 0.0f, b.W ? 1.0f : 0.0f);
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

    public static float length(float2 value) => (float)System.Math.Sqrt(lengthSq(value));

    public static float length(float3 value) => (float)System.Math.Sqrt(lengthSq(value));

    public static float length(float4 value) => (float)System.Math.Sqrt(lengthSq(value));



    public static float distanceSq(float2 left, float2 right) => dot(left, right);

    public static float distanceSq(float3 left, float3 right) => dot(left, right);

    public static float distanceSq(float4 left, float4 right) => dot(left, right);

    public static float distance(float2 left, float2 right) => (float)System.Math.Sqrt(distanceSq(left, right));

    public static float distance(float3 left, float3 right) => (float)System.Math.Sqrt(distanceSq(left, right));

    public static float distance(float4 left, float4 right) => (float)System.Math.Sqrt(distanceSq(left, right));

    #endregion

    public static float3 cross(float3 left, float3 right)
    {
        return new float3(
            left.Y * right.Z - left.Z * right.Y,
            left.Z * right.X - left.X * right.Z,
            left.X * right.Y - left.Y * right.X);
    }

    // transpose und determinante für Matrizen

    #region Trigonometric Functions

    /// <summary>
    /// Returns the tangent of the specified value.
    /// </summary>
    /// <param name="value">The specified value, in radians.</param>
    /// <returns>The tangent of the value.</returns>
    public static float tan(float value) => (float)System.Math.Tan(value);

    /// <inheritdoc cref="tan(float)"/>
    public static float2 tan(float2 value) => new((float)System.Math.Tan(value.X), (float)System.Math.Tan(value.Y));

    /// <inheritdoc cref="tan(float)"/>
    public static float3 tan(float3 value) => new((float)System.Math.Tan(value.X), (float)System.Math.Tan(value.Y),
        (float)System.Math.Tan(value.Z));

    /// <inheritdoc cref="tan(float)"/>
    public static float4 tan(float4 value) => new((float)System.Math.Tan(value.X), (float)System.Math.Tan(value.Y),
        (float)System.Math.Tan(value.Z), (float)System.Math.Tan(value.W));

    /// <summary>
    /// Returns the sine of the specified value.
    /// </summary>
    /// <param name="value">The specified value, in radians.</param>
    /// <returns>The sine of the value.</returns>
    public static float sin(float value) => (float)System.Math.Sin(value);

    /// <inheritdoc cref="sin(float)"/>
    public static float2 sin(float2 value) => new((float)System.Math.Sin(value.X), (float)System.Math.Sin(value.Y));

    /// <inheritdoc cref="sin(float)"/>
    public static float3 sin(float3 value) => new((float)System.Math.Sin(value.X), (float)System.Math.Sin(value.Y),
        (float)System.Math.Sin(value.Z));

    /// <inheritdoc cref="sin(float)"/>
    public static float4 sin(float4 value) => new((float)System.Math.Sin(value.X), (float)System.Math.Sin(value.Y),
        (float)System.Math.Sin(value.Z), (float)System.Math.Sin(value.W));

    /// <summary>
    /// Returns the cosine of the specified value.
    /// </summary>
    /// <param name="value">The specified value, in radians.</param>
    /// <returns>The cosine of the value.</returns>
    public static float cos(float value) => (float)System.Math.Cos(value);

    /// <inheritdoc cref="cos(float)"/>
    public static float2 cos(float2 value) => new((float)System.Math.Cos(value.X), (float)System.Math.Cos(value.Y));

    /// <inheritdoc cref="cos(float)"/>
    public static float3 cos(float3 value) => new((float)System.Math.Cos(value.X), (float)System.Math.Cos(value.Y),
        (float)System.Math.Cos(value.Z));

    /// <inheritdoc cref="cos(float)"/>
    public static float4 cos(float4 value) => new((float)System.Math.Cos(value.X), (float)System.Math.Cos(value.Y),
        (float)System.Math.Cos(value.Z), (float)System.Math.Cos(value.W));

    /// <summary>
    /// Returns the arcsine of the specified value.
    /// </summary>
    /// <param name="value">The specified value.</param>
    /// <returns>The arcsine of the value.</returns>
    public static float asin(float value) => (float)System.Math.Asin(value);

    /// <inheritdoc cref="asin(float)"/>
    public static float2 asin(float2 value) => new((float)System.Math.Asin(value.X), (float)System.Math.Asin(value.Y));

    /// <inheritdoc cref="asin(float)"/>
    public static float3 asin(float3 value) => new((float)System.Math.Asin(value.X), (float)System.Math.Asin(value.Y),
        (float)System.Math.Asin(value.Z));

    /// <inheritdoc cref="asin(float)"/>
    public static float4 asin(float4 value) => new((float)System.Math.Asin(value.X), (float)System.Math.Asin(value.Y),
        (float)System.Math.Asin(value.Z), (float)System.Math.Asin(value.W));

    /// <summary>
    /// Returns the arccosine of the specified value.
    /// </summary>
    /// <param name="value">The specified value.</param>
    /// <returns>The arccosine of the value.</returns>
    public static float acos(float value) => (float)System.Math.Acos(value);

    /// <inheritdoc cref="acos(float)"/>
    public static float2 acos(float2 value) => new((float)System.Math.Acos(value.X), (float)System.Math.Acos(value.Y));

    /// <inheritdoc cref="acos(float)"/>
    public static float3 acos(float3 value) => new((float)System.Math.Acos(value.X), (float)System.Math.Acos(value.Y),
        (float)System.Math.Acos(value.Z));

    /// <inheritdoc cref="acos(float)"/>
    public static float4 acos(float4 value) => new((float)System.Math.Acos(value.X), (float)System.Math.Acos(value.Y),
        (float)System.Math.Acos(value.Z), (float)System.Math.Acos(value.W));

    /// <summary>
    /// Returns the arctangent of the specified value.
    /// </summary>
    /// <param name="value">The specified value.</param>
    /// <returns>The arctangent of the value.</returns>
    public static float atan(float value) => (float)System.Math.Atan(value);

    /// <inheritdoc cref="atan(float)"/>
    public static float2 atan(float2 value) => new((float)System.Math.Atan(value.X), (float)System.Math.Atan(value.Y));

    /// <inheritdoc cref="atan(float)"/>
    public static float3 atan(float3 value) => new((float)System.Math.Atan(value.X), (float)System.Math.Atan(value.Y),
        (float)System.Math.Atan(value.Z));

    /// <inheritdoc cref="atan(float)"/>
    public static float4 atan(float4 value) => new((float)System.Math.Atan(value.X), (float)System.Math.Atan(value.Y),
        (float)System.Math.Atan(value.Z), (float)System.Math.Atan(value.W));
    
    /// <summary>
    /// Returns the arctangent of two values (x,y).
    /// </summary>
    /// <param name="y">The y value.</param>
    /// <param name="x">The x value.</param>
    /// <returns>The arctangent of (y,x).</returns>
    public static float atan2(float y, float x) => (float)System.Math.Atan2(y, x);
    
    /// <inheritdoc cref="atan2(float, float)"/>
    public static float2 atan2(float2 y, float2 x) =>
        new((float)System.Math.Atan2(y.X, x.X), (float)System.Math.Atan2(y.Y, x.Y));
    
    /// <inheritdoc cref="atan2(float, float)"/>
    public static float3 atan2(float3 y, float3 x) => new((float)System.Math.Atan2(y.X, x.X),
        (float)System.Math.Atan2(y.Y, x.Y), (float)System.Math.Atan2(y.Z, x.Z));
    
    /// <inheritdoc cref="atan2(float, float)"/>
    public static float4 atan2(float4 y, float4 x) => new((float)System.Math.Atan2(y.X, x.X),
        (float)System.Math.Atan2(y.Y, x.Y), (float)System.Math.Atan2(y.Z, x.Z), (float)System.Math.Atan2(y.W, x.W));

    /// <summary>
    /// Returns the hyperbolic sine of the specified value.
    /// </summary>
    /// <param name="value">The specified value.</param>
    /// <returns>The hyperbolic sine of the value.</returns>
    public static float sinh(float value) => (float)System.Math.Sinh(value);

    /// <inheritdoc cref="sinh(float)"/>
    public static float2 sinh(float2 value) => new((float)System.Math.Sinh(value.X), (float)System.Math.Sinh(value.Y));

    /// <inheritdoc cref="sinh(float)"/>
    public static float3 sinh(float3 value) => new((float)System.Math.Sinh(value.X), (float)System.Math.Sinh(value.Y),
        (float)System.Math.Sinh(value.Z));

    /// <inheritdoc cref="sinh(float)"/>
    public static float4 sinh(float4 value) => new((float)System.Math.Sinh(value.X), (float)System.Math.Sinh(value.Y),
        (float)System.Math.Sinh(value.Z), (float)System.Math.Sinh(value.W));

    /// <summary>
    /// Returns the hyperbolic cosine of the specified value.
    /// </summary>
    /// <param name="value">The specified value.</param>
    /// <returns>The hyperbolic cosine of the value.</returns>
    public static float cosh(float value) => (float)System.Math.Cosh(value);

    /// <inheritdoc cref="cosh(float)"/>
    public static float2 cosh(float2 value) => new((float)System.Math.Cosh(value.X), (float)System.Math.Cosh(value.Y));

    /// <inheritdoc cref="cosh(float)"/>
    public static float3 cosh(float3 value) => new((float)System.Math.Cosh(value.X), (float)System.Math.Cosh(value.Y),
        (float)System.Math.Cosh(value.Z));

    /// <inheritdoc cref="cosh(float)"/>
    public static float4 cosh(float4 value) => new((float)System.Math.Cosh(value.X), (float)System.Math.Cosh(value.Y),
        (float)System.Math.Cosh(value.Z), (float)System.Math.Cosh(value.W));

    /// <summary>
    /// Returns the hyperbolic tangent of the specified value.
    /// </summary>
    /// <param name="value">The specified value.</param>
    /// <returns>The hyperbolic tangent of the value.</returns>
    public static float tanh(float value) => (float)System.Math.Tanh(value);

    /// <inheritdoc cref="tanh(float)"/>
    public static float2 tanh(float2 value) => new((float)System.Math.Tanh(value.X), (float)System.Math.Tanh(value.Y));

    /// <inheritdoc cref="tanh(float)"/>
    public static float3 tanh(float3 value) => new((float)System.Math.Tanh(value.X), (float)System.Math.Tanh(value.Y), (float)System.Math.Tanh(value.Z));
    
    /// <inheritdoc cref="tanh(float)"/>
    public static float4 tanh(float4 value) => new((float)System.Math.Tanh(value.X), (float)System.Math.Tanh(value.Y), (float)System.Math.Tanh(value.Z), (float)System.Math.Tanh(value.W));
    
    #endregion
}
