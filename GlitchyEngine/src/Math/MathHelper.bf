namespace GlitchyEngine.Math
{
	public static class MathHelper
	{
		public const float Pi = 3.14159265359f;
		public const float TwoPi = 6.28318530718f;
		public const float PiOverTwo = 1.57079632679f;
		public const float PiOverThree = 1.0471975511965f;
		public const float PiOverFour =  0.7853981633974f;

		/// Converts radians to degrees
		const float RadToDeg = 180.0f / Pi;

		/// Converts radians to degrees
		const float DegToRad = Pi / 180.0f;

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
	}
}
