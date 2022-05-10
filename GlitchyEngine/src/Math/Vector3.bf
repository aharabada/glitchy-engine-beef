using System;

namespace GlitchyEngine.Math
{
	[SwizzleVector(3, "Vector")]
	public struct Vector3
	{
		public const Vector3 Zero     = .(0f, 0f, 0f);
		public const Vector3 UnitX    = .(1f, 0f, 0f);
		public const Vector3 UnitY    = .(0f, 1f, 0f);
		public const Vector3 UnitZ    = .(0f, 0f, 1f);
		public const Vector3 One      = .(1f, 1f, 1f);
		
		public const Vector3 Forward  = .(0f, 0f, 1f);	
		public const Vector3 Backward = .(0f, 0f, -1f);	
		public const Vector3 Left     = .(-1f, 0f, 0f); 	
		public const Vector3 Right    = .(1f, 0f, 0f);  	
		public const Vector3 Up       = .(0f, 1f, 0f); 	
		public const Vector3 Down     = .(0f, -1f, 0f);
		
		public const int ComponentCount = 3;

		public float X, Y, Z;

		public this() => this = default;

		public this(float value)
		{
			X = value;
			Y = value;
			Z = value;
		}

		public this(Vector2 value, float z = 0.0f)
		{
			X = value.X;
			Y = value.Y;
			Z = z;
		}

		public this(float x, float y, float z)
		{
			X = x;
			Y = y;
			Z = z;
		}

		public this(Vector3 value)
		{
			X = value.X;
			Y = value.Y;
			Z = value.Z;
		}

		public this(Vector4 value)
		{
			X = value.X;
			Y = value.Y;
			Z = value.Z;
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
			get
			{
				switch(index)
				{
				case 0: return X;
				case 1: return Y;
				case 2: return Z;
				default: Internal.ThrowIndexOutOfRange(1);
				}
			}

			set mut
			{
				switch(index)
				{
				case 0: X = value;
				case 1: Y = value;
				case 2: Z = value;
				default: Internal.ThrowIndexOutOfRange(1);
				}
			}
		}

		/**
		 * Calculates the magnitude (length) of this vector.
		 * @remarks If the exact magnitude isn't needed (e.g. for comparisons) consider using MagnitudeSquared which doesn't use the square root operation.
		 */
		public float Magnitude() => Math.Sqrt(X * X + Y * Y + Z * Z);
		
		/**
		 * Calculates the squared magnitude (length) of this vector.
		 * @remarks This function avoids the square root operation to calculate the magnitude and is thus more suitable for comparisons where the exact magnitude isn't needed.
		 */
		public float MagnitudeSquared() => X * X + Y * Y + Z * Z;

		/// Normalizes this vector.
		[Checked]
		public void Normalize() mut
		{
			if(this == .Zero)
				return;

			this /= Magnitude();
		}

		/// Normalizes this vector.
		public void Normalize() mut
		{
			this /= Magnitude();
		}
		
		/// Returns a copy of this Vector with a magnitude of 1.
		[Checked]
		public Vector3 Normalized()
		{
			if(this == .Zero)
				return .Zero;

			return this / Magnitude();
		}

		/// Returns a copy of this Vector with a magnitude of 1.
		public Vector3 Normalized()
		{
			return this / Magnitude();
		}
		
		/// Returns a copy of the given Vector with a magnitude of 1.
		public static Vector3 Normalize(Vector3 v)
		{
			return v / v.Magnitude();
		}

		/// Calculates the dot product of two vectors.
		public static float Dot(Vector3 l, Vector3 r) => l.X * r.X + l.Y * r.Y + l.Z * r.Z;

		/// Calculates the distance between two vectors.
		public static float Distance(Vector3 a, Vector3 b) => (a - b).[Inline]Magnitude();

		/// Calculates the squared distance between two vectors.
		public static float DistanceSquared(Vector3 a, Vector3 b) => (a - b).[Inline]MagnitudeSquared();
		
		/// Calculates the cross product of two vectors.
		public static Vector3 Cross(Vector3 l, Vector3 r)
		{
			return .(l.Y * r.Z - l.Z * r.Y,
					 l.Z * r.X - l.X * r.Z,
					 l.X * r.Y - l.Y * r.X);
		}

		/// Calculates the projection of a onto b.
		public static Vector3 Project(Vector3 a, Vector3 b)
		{
			return (b * (Dot(a, b) / Dot(b, b)));
		}

		/// Calculates the rejection of a from b.
		public static Vector3 Reject(Vector3 a, Vector3 b)
		{
			return (a - b * (Dot(a, b) / Dot(b, b)));
		}

		public static Vector3 Floor(Vector3 value) => .(Math.Floor(value.X), Math.Floor(value.Y), Math.Floor(value.Z));

		public static Vector3 Ceiling(Vector3 value) => .(Math.Ceiling(value.X), Math.Ceiling(value.Y), Math.Ceiling(value.Z));
		
		/**
		 * Interpolates linearly between two given vectors.
		 * @param a The first vector.
		 * @param b The second vector.
		 * @param interpolationValue The value that linearly interpolates between a and b.
		 *        (0 means a will be returned, 1 means b will be returned.)
		 * @returns The resulting linear interpolation.
		 */
		public static Vector3 Lerp(Vector3 a, Vector3 b, float interpolationValue)
		{
			return a + interpolationValue * (b - a);
		}
		
		public static Vector3 Min(Vector3 a, Vector3 b) => .(Math.Min(a.X, b.X), Math.Min(a.Y, b.Y), Math.Min(a.Z, b.Z));

		public static Vector3 Max(Vector3 a, Vector3 b) => .(Math.Max(a.X, b.X), Math.Max(a.Y, b.Y), Math.Min(a.Z, b.Z));
		
		public static Vector3 Abs(Vector3 v) => .(Math.Abs(v.X), Math.Abs(v.Y), Math.Abs(v.Z));

		public static Vector3 Clamp(Vector3 v, Vector3 min, Vector3 max)
		{
			return .(Math.Clamp(v.X, min.X, max.X),
			         Math.Clamp(v.Y, min.Y, max.Y),
			         Math.Clamp(v.X, min.Z, max.Z));
		}

		//
		// Assignment operators
		//
		
		// Addition

		public void operator +=(Vector3 value) mut
		{
			X += value.X;
			Y += value.Y;
			Z += value.Z;
		}

		public void operator +=(float scalar) mut
		{
			X += scalar;
			Y += scalar;
			Z += scalar;
		}

		// Subtraction

		public void operator -=(Vector3 value) mut
		{
			X -= value.X;
			Y -= value.Y;
			Z -= value.Z;
		}

		public void operator -=(float scalar) mut
		{
			X -= scalar;
			Y -= scalar;
			Z -= scalar;
		}

		// Multiplication

		public void operator *=(Vector3 value) mut
		{
			X *= value.X;
			Y *= value.Y;
			Z *= value.Z;
		}

		public void operator *=(float scalar) mut
		{
			X *= scalar;
			Y *= scalar;
			Z *= scalar;
		}

		// Division

		public void operator /=(Vector3 value) mut
		{
			X /= value.X;
			Y /= value.Y;
			Z /= value.Z;
		}

		public void operator /=(float scalar) mut
		{
			float inv = 1.0f / scalar;
			X *= inv;
			Y *= inv;
			Z *= inv;
		}

		//
		// operators
		//

		// Addition

		public static Vector3 operator +(Vector3 left, Vector3 right) => Vector3(left.X + right.X, left.Y + right.Y, left.Z + right.Z);

		public static Vector3 operator +(Vector3 value, float scalar) => Vector3(value.X + scalar, value.Y + scalar, value.Z + scalar);
		
		public static Vector3 operator +(float scalar, Vector3 value) => Vector3(scalar + value.X, scalar + value.Y, scalar + value.Z);

		public static Vector3 operator +(Vector3 value) => value;
		
		// Subtraction

		public static Vector3 operator -(Vector3 left, Vector3 right) => Vector3(left.X - right.X, left.Y - right.Y, left.Z - right.Z);

		public static Vector3 operator -(Vector3 value, float scalar) => Vector3(value.X - scalar, value.Y - scalar, value.Z - scalar);

		public static Vector3 operator -(float scalar, Vector3 value) => Vector3(scalar - value.X, scalar - value.Y, scalar - value.Z);

		public static Vector3 operator -(Vector3 value) => Vector3(-value.X, -value.Y, -value.Z);

		// Multiplication

		public static Vector3 operator *(Vector3 left, Vector3 right) => Vector3(left.X * right.X, left.Y * right.Y, left.Z * right.Z);

		public static Vector3 operator *(Vector3 value, float scalar) => Vector3(value.X * scalar, value.Y * scalar, value.Z * scalar);

		public static Vector3 operator *(float scalar, Vector3 value) => Vector3(scalar * value.X, scalar * value.Y, scalar * value.Z);

		// Division

		public static Vector3 operator /(Vector3 left, Vector3 right) => Vector3(left.X / right.X, left.Y / right.Y, left.Z / right.Z);

		public static Vector3 operator /(Vector3 value, float scalar)
		{	
			float inv = 1.0f / scalar;
			return Vector3(value.X * inv, value.Y * inv, value.Z * inv);
		}

		public static Vector3 operator /(float scalar, Vector3 value) => Vector3(scalar / value.X, scalar / value.Y, scalar / value.Z);
		
		// Modulo

		public static Vector3 operator %(Vector3 left, Vector3 right) => Vector3(left.X % right.X, left.Y % right.Y, left.Z % right.Z);

		public static Vector3 operator %(Vector3 value, float scalar) => Vector3(value.X % scalar, value.Y % scalar, value.Z % scalar);

		public static Vector3 operator %(float scalar, Vector3 value) => Vector3(scalar % value.X, scalar % value.Y, scalar % value.Z);

		// Equality

		public static bool operator ==(Vector3 left, Vector3 right) => left.X == right.X && left.Y == right.Y && left.Z == right.Z;

		public static bool operator !=(Vector3 left, Vector3 right) => left.X != right.X || left.Y != right.Y || left.Z != right.Z;

		public override void ToString(String strBuffer) => strBuffer.AppendF("X:{0} Y:{1} Z:{2}", X, Y, Z);

		[Inline]
		public static explicit operator Self(float value) => Self(value);

		[Inline]
#unwarn
		public static explicit operator float[3](Vector3 value) => *(float[3]*)&value;
	}
}
