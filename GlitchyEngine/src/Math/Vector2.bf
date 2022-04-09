using System;

namespace GlitchyEngine.Math
{
	[SwizzleVector(2, "Vector")]
	public struct Vector2
	{
		public const Vector2 Zero  = .(0f, 0f);
		public const Vector2 UnitX = .(1f, 0f);
		public const Vector2 UnitY = .(0f, 1f);
		public const Vector2 One   = .(1f, 1f);

		public const int ComponentCount = 2;
		
		public float X, Y;

		public this() => this = default;

		public this(float value)
		{
			X = value;
			Y = value;
		}

		public this(float x, float y)
		{
			X = x;
			Y = y;
		}
		
		public ref float this[int index]
		{
			[Checked]
			get mut
			{
				if(index < 0 || index >= ComponentCount)
					Internal.ThrowIndexOutOfRange(1);
				
				return ref (&X)[index];
			}

			[Inline]
			get mut => ref (&X)[index];
		}
		
		public float this[int index]
		{
			[Checked]
			get
			{
				if(index < 0 || index >= ComponentCount)
					Internal.ThrowIndexOutOfRange(1);
				
				if(index == 0)
					return X;
				else
					return Y;
			}

			[Inline]
			get
			{
				if(index == 0)
					return X;
				else
					return Y;
			}
			
			[Checked]
			set mut
			{
				if(index < 0 || index >= ComponentCount)
					Internal.ThrowIndexOutOfRange(1);
				
				if(index == 0)
					X = value;
				else
					Y = value;
			}

			[Inline]
			set mut
			{
				if(index == 0)
					X = value;
				else
					Y = value;
			}
		}

		/**
		 * Calculates the magnitude (length) of this vector.
		 * @remarks MagnitudeSquared might be used if only the relative length is relevant.
		 */
		public float Magnitude()
		{
			return Math.Sqrt(X * X + Y * Y);
		}

		/**
		 * Calculates the squared magnitude (length) of this vector.
		 */
		public float MagnitudeSquared()
		{
			return X * X + Y * Y;
		}

		//TODO: Normalization interface is bad
		[Checked]
		public void Normalize() mut
		{
			if(this == .Zero)
				return;

			this /= Magnitude();
		}

		public void Normalize() mut
		{
			this /= Magnitude();
		}

		public static Vector2 Normalize(Vector2 v)
		{
			return v / v.Magnitude();
		}

		public static float Dot(Vector2 l, Vector2 r)
		{
			return l.X * r.X + l.Y * r.Y;
		}

		/**
		* Calculates the projection of a onto b
		*/
		public static Vector2 Project(Vector2 a, Vector2 b)
		{
			return (b * (Dot(a, b) / Dot(b, b)));
		}

		/**
		* Calculates the rejection of a from b
		*/
		public static Vector2 Reject(Vector2 a, Vector2 b)
		{
			return (a - b * (Dot(a, b) / Dot(b, b)));
		}
		
		/**
		 * Interpolates linearly between two given vectors.
		 * @param a The first vector.
		 * @param b The second vector.
		 * @param interpolationValue The value that linearly interpolates between a and b.
		 *        (0 means a will be returned, 1 means b will be returned.)
		 * @returns The resulting linear interpolation.
		 */
		public static Vector2 Lerp(Vector2 a, Vector2 b, float interpolationValue)
		{
			return a + interpolationValue * (b - a);
		}

		public static Vector2 Min(Vector2 a, Vector2 b)
		{
			return .(Math.Min(a.X, b.X), Math.Min(a.Y, b.Y));
		}

		public static Vector2 Max(Vector2 a, Vector2 b)
		{
			return .(Math.Max(a.X, b.X), Math.Max(a.Y, b.Y));
		}

		//
		// Assignment operators
		//

		// Addition

		public void operator +=(Vector2 value) mut
		{
			X += value.X;
			Y += value.Y;
		}

		public void operator +=(float scalar) mut
		{
			X += scalar;
			Y += scalar;
		}

		// Subtraction

		public void operator -=(Vector2 value) mut
		{
			X -= value.X;
			Y -= value.Y;
		}

		public void operator -=(float scalar) mut
		{
			X -= scalar;
			Y -= scalar;
		}

		// Multiplication

		public void operator *=(Vector2 value) mut
		{
			X *= value.X;
			Y *= value.Y;
		}

		public void operator *=(float scalar) mut
		{
			X *= scalar;
			Y *= scalar;
		}

		// Division

		public void operator /=(float scalar) mut
		{
			float f = 1.0f / scalar;
			X *= f;
			Y *= f;
		}

		public void operator /=(Vector2 value) mut
		{
			X /= value.X;
			Y /= value.Y;
		}

		//
		// operators
		//

		// Addition

		public static Vector2 operator +(Vector2 left, Vector2 right) => Vector2(left.X + right.X, left.Y + right.Y);

		public static Vector2 operator +(Vector2 value, float scalar) => Vector2(value.X + scalar, value.Y + scalar);

		public static Vector2 operator +(float scalar, Vector2 value) => Vector2(scalar + value.X, scalar + value.Y);

		public static Vector2 operator +(Vector2 value) => value;

		// Subtraction

		public static Vector2 operator -(Vector2 left, Vector2 right) => Vector2(left.X - right.X, left.Y - right.Y);

		public static Vector2 operator -(Vector2 value, float scalar) => Vector2(value.X - scalar, value.Y - scalar);

		public static Vector2 operator -(float scalar, Vector2 value) => Vector2(scalar - value.X, scalar - value.Y);

		public static Vector2 operator -(Vector2 value) => Vector2(-value.X, -value.Y);

		// Multiplication

		public static Vector2 operator *(Vector2 left, Vector2 right) => Vector2(left.X * right.X, left.Y * right.Y);

		public static Vector2 operator *(Vector2 value, float scalar) => Vector2(value.X * scalar, value.Y * scalar);

		public static Vector2 operator *(float scalar, Vector2 value) => Vector2(scalar * value.X, scalar * value.Y);

		// Division

		public static Vector2 operator /(Vector2 left, Vector2 right) => Vector2(left.X / right.X, left.Y / right.Y);

		public static Vector2 operator /(Vector2 value, float scalar)
		{	
			float inv = 1.0f / scalar;
			return Vector2(value.X * inv, value.Y * inv);
		}

		public static Vector2 operator /(float scalar, Vector2 value) => Vector2(scalar / value.X, scalar / value.Y);

		// Equality

		public static bool operator ==(Vector2 left, Vector2 right) => left.X == right.X && left.Y == right.Y;

		public static bool operator !=(Vector2 left, Vector2 right) => left.X != right.X || left.Y != right.Y;

		public override void ToString(String strBuffer) => strBuffer.AppendF("X:{0} Y:{1}", X, Y);

		[Inline]
		public static explicit operator Self(float value) => Self(value);

		public bool Equals(Vector2 v, float epsilon = Math.[Friend]sMachineEpsilonFloat)
		{
			return (Math.Abs(v.X - X) < epsilon) && (Math.Abs(v.Y - Y) < epsilon);
		}
	}
}
