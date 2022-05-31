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
		public static Vector2 ToDegrees(Vector2 radians)
		{
			return radians * RadToDeg;
		}
		
		// Converts the given radians to degrees
		public static Vector3 ToDegrees(Vector3 radians)
		{
			return radians * RadToDeg;
		}
		
		// Converts the given radians to degrees
		public static Vector4 ToDegrees(Vector4 radians)
		{
			return radians * RadToDeg;
		}

		// Converts the given degrees to radians
		public static float ToRadians(float degrees)
		{
			return degrees * DegToRad;
		}

		// Converts the given degrees to radians
		public static Vector2 ToRadians(Vector2 degrees)
		{
			return degrees * DegToRad;
		}

		// Converts the given degrees to radians
		public static Vector3 ToRadians(Vector3 degrees)
		{
			return degrees * DegToRad;
		}

		// Converts the given degrees to radians
		public static Vector4 ToRadians(Vector4 degrees)
		{
			return degrees * DegToRad;
		}

		const float epsilon = 0.0000001f;

		public static bool IsZero(float value)
		{
			return Math.Abs(value) < epsilon;
		}

		/// Returns the point that lies on the unit circle at the specified angle.
		public static Vector2 CirclePoint(float angle, float radius = 1.0f)
		{
			return .(Math.Cos(angle), Math.Sin(angle)) * radius;
		}

		public static Vector2 Pow(Vector2 v, float p)
		{
			return Vector2(Math.Pow(v.X, p), Math.Pow(v.Y, p));
		}

		public static Vector3 Pow(Vector3 v, float p)
		{
			return Vector3(Math.Pow(v.X, p), Math.Pow(v.Y, p), Math.Pow(v.Z, p));
		}

		public static Vector4 Pow(Vector4 v, float p)
		{
			return Vector4(Math.Pow(v.X, p), Math.Pow(v.Y, p), Math.Pow(v.Z, p), Math.Pow(v.W, p));
		}
	}
}
