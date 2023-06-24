using System;

namespace GlitchyEngine.Math
{
	public static class MathHelper
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

		// Converts the given radians to degrees
		public static float ToDegrees(float radians)
		{
			return radians * RadToDeg;
		}
		
		// Converts the given radians to degrees
		public static float2 ToDegrees(float2 radians)
		{
			return radians * RadToDeg;
		}
		
		// Converts the given radians to degrees
		public static float3 ToDegrees(float3 radians)
		{
			return radians * RadToDeg;
		}
		
		// Converts the given radians to degrees
		public static float4 ToDegrees(float4 radians)
		{
			return radians * RadToDeg;
		}

		// Converts the given degrees to radians
		public static float ToRadians(float degrees)
		{
			return degrees * DegToRad;
		}

		// Converts the given degrees to radians
		public static float2 ToRadians(float2 degrees)
		{
			return degrees * DegToRad;
		}

		// Converts the given degrees to radians
		public static float3 ToRadians(float3 degrees)
		{
			return degrees * DegToRad;
		}

		// Converts the given degrees to radians
		public static float4 ToRadians(float4 degrees)
		{
			return degrees * DegToRad;
		}

		const float epsilon = 0.0000001f;

		public static bool IsZero(float value)
		{
			return Math.Abs(value) < epsilon;
		}

		/// Returns the point that lies on the unit circle at the specified angle.
		public static float2 CirclePoint(float angle, float radius = 1.0f)
		{
			return .(Math.Cos(angle), Math.Sin(angle)) * radius;
		}

		public static float2 Pow(float2 v, float p)
		{
			return float2(Math.Pow(v.X, p), Math.Pow(v.Y, p));
		}

		public static float3 Pow(float3 v, float p)
		{
			return float3(Math.Pow(v.X, p), Math.Pow(v.Y, p), Math.Pow(v.Z, p));
		}

		public static float4 Pow(float4 v, float p)
		{
			return float4(Math.Pow(v.X, p), Math.Pow(v.Y, p), Math.Pow(v.Z, p), Math.Pow(v.W, p));
		}
	}
}
