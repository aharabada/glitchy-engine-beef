using System;

namespace GlitchyEngine.Math
{
	//[SwizzleVector(3, "Vector")]
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
		
		public const int Length = 3;

		public float X, Y, Z;

		public this() => this = default;

		public this(float value)
		{
			X = value;
			Y = value;
			Z = value;
		}

		public this(Vector2 value, float z)
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
		
		public ref float this[int index]
		{
			[Checked]
			get mut
			{
				if(index < 0 || index >= Length)
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
				default: Internal.ThrowIndexOutOfRange();
				}
			}

			set mut
			{
				switch(index)
				{
				case 0: X = value;
				case 1: Y = value;
				case 2: Z = value;
				default: Internal.ThrowIndexOutOfRange();
				}
			}
		}

		/**
		 * Calculates the magnitude (length) of this vector.
		 * @remarks MagnitudeSquared might be used if only the relative length is relevant.
		 */
		public float Magnitude()
		{
			return Math.Sqrt(X * X + Y * Y + Z * Z);
		}
		
		/**
		 * Calculates the squared magnitude (length) of this vector.
		 */
		public float MagnitudeSquared()
		{
			return X * X + Y * Y + Z * Z;
		}
		
		/**
		 * Normalizes this vector.
		 */
		[Checked]
		public void Normalize() mut
		{
			if(this == .Zero)
				return;

			this /= Magnitude();
		}

		/**
		 * Normalizes this vector.
		 */
		public void Normalize() mut
		{
			this /= Magnitude();
		}
		
		/**
		 * Returns a copy of this Vector with a magnitude of 1.
		 */
		[Checked]
		public Vector3 Normalized()
		{
			if(this == .Zero)
				return .Zero;

			return this / Magnitude();
		}

		/**
		 * Returns a copy of this Vector with a magnitude of 1.
		 */
		public Vector3 Normalized()
		{
			return this / Magnitude();
		}

		public static Vector3 Normalize(Vector3 v)
		{
			return v / v.Magnitude();
		}

		public static float Dot(Vector3 l, Vector3 r)
		{
			return l.X * r.X + l.Y * r.Y + l.Z * r.Z;
		}

		public static Vector3 Cross(Vector3 l, Vector3 r)
		{
			return .(l.Y * r.Z - l.Z * r.Y,
					 l.Z * r.X - l.X * r.Z,
					 l.X * r.Y - l.Y * r.X);
		}

		/**
		* Calculates the projection of a onto b
		*/
		public static Vector3 Project(Vector3 a, Vector3 b)
		{
			return (b * (Dot(a, b) / Dot(b, b)));
		}


		/**
		* Calculates the rejection of a from b
		*/
		public static Vector3 Reject(Vector3 a, Vector3 b)
		{
			return (a - b * (Dot(a, b) / Dot(b, b)));
		}

		public static Vector3 Floor(Vector3 value)
		{
			return .(Math.Floor(value.X), Math.Floor(value.Y), Math.Floor(value.Z));
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

		// Todo: move to extension

		[Inline]
		public static implicit operator DirectX.Math.Vector3(in Self value) => *(DirectX.Math.Vector3*)&value;

		[Inline]
		public static implicit operator Self(in DirectX.Math.Vector3 value) => *(Self*)&value;

		[Inline]
		public static explicit operator Self(float value) => Self(value);
	}
}
