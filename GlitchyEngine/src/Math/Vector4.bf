using Bon;
using System;

namespace GlitchyEngine.Math
{
	[BonTarget]
	[SwizzleVector(4, "GlitchyEngine.Math.Vector")]
	public struct float4
	{
		public const float4 Zero 	= .(0f, 0f, 0f, 0f);
		public const float4 UnitX 	= .(1f, 0f, 0f, 0f);
		public const float4 UnitY 	= .(0f, 1f, 0f, 0f);
		public const float4 UnitZ 	= .(0f, 0f, 1f, 0f);
		public const float4 UnitW 	= .(0f, 0f, 0f, 1f);
		public const float4 One 	= .(1f, 1f, 1f, 1f);
		
		public const int ComponentCount = 4;

		public float X, Y, Z, W;

		public this() => this = default;

		public this(float value)
		{
			X = value;
			Y = value;
			Z = value;
			W = value;
		}
		
		public this(Vector2 value, float z, float w)
		{
			X = value.X;
			Y = value.Y;
			Z = z;
			W = w;
		}
		
		public this(Vector2 value1, Vector2 value2)
		{
			X = value1.X;
			Y = value1.Y;
			Z = value2.X;
			W = value2.Y;
		}

		public this(float3 value, float w)
		{
			X = value.X;
			Y = value.Y;
			Z = value.Z;
			W = w;
		}

		public this(float x, float y, float z, float w)
		{
			X = x;
			Y = y;
			Z = z;
			W = w;
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
				case 3: return W;
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
				case 3: W = value;
				default: Internal.ThrowIndexOutOfRange(1);
				}
			}
		}

		/**
		 * Calculates the magnitude (length) of this vector.
		 * @remarks MagnitudeSquared might be used if only the relative length is relevant.
		 */
		public float Magnitude()
		{
			return Math.Sqrt(X * X + Y * Y + Z * Z + W * W);
		}

		/**
		 * Calculates the squared magnitude (length) of this vector.
		 */
		public float MagnitudeSquared()
		{
			return X * X + Y * Y + Z * Z + W * W;
		}
		
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
		
		public static float4 Normalize(float4 v)
		{
			if(v == .Zero)
				return .Zero;

			return v / v.Magnitude();
		}
		
		[Unchecked]
		public static float4 Normalize(float4 v)
		{
			return v / v.Magnitude();
		}

		public static float Dot(float4 l, float4 r)
		{
			return l.X * r.X + l.Y * r.Y + l.Z * r.Z + l.W * r.W;
		}

		/**
		 * Calculates the projection of a onto b
		 */
		public static float4 Project(float4 a, float4 b)
		{
			return (b * (Dot(a, b) / Dot(b, b)));
		}

		/**
		 * Calculates the rejection of a from b
		 */
		public static float4 Reject(float4 a, float4 b)
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
		public static float4 Lerp(float4 a, float4 b, float interpolationValue)
		{
			return a + interpolationValue * (b - a);
		}
		
		public static float4 Min(float4 a, float4 b)
		{
			return .(Math.Min(a.X, b.X), Math.Min(a.Y, b.Y), Math.Min(a.Z, b.Z), Math.Min(a.W, b.W));
		}

		public static float4 Max(float4 a, float4 b)
		{
			return .(Math.Max(a.X, b.X), Math.Max(a.Y, b.Y), Math.Min(a.Z, b.Z), Math.Min(a.W, b.W));
		}

		//
		// Assignment operators
		//

		// Addition
		
		public void operator +=(float4 value) mut
		{
			X += value.X;
			Y += value.Y;
			Z += value.Z;
			W += value.W;
		}
		
		public void operator +=(float scalar) mut
		{
			X += scalar;
			Y += scalar;
			Z += scalar;
			W += scalar;
		}

		// Subtraction

		public void operator -=(float4 value) mut
		{
			X -= value.X;
			Y -= value.Y;
			Z -= value.Z;
			W -= value.W;
		}

		public void operator -=(float scalar) mut
		{
			X -= scalar;
			Y -= scalar;
			Z -= scalar;
			W -= scalar;
		}

		// Multiplication
		
		public void operator *=(float4 value) mut
		{
			X *= value.X;
			Y *= value.Y;
			Z *= value.Z;
			W *= value.W;
		}

		public void operator *=(float scalar) mut
		{
			X *= scalar;
			Y *= scalar;
			Z *= scalar;
			W *= scalar;
		}

		// Division

		public void operator /=(float scalar) mut
		{
			float f = 1.0f / scalar;
			X *= f;
			Y *= f;
			Z *= f;
			W *= f;
		}

		public void operator /=(float4 value) mut
		{
			X /= value.X;
			Y /= value.Y;
			Z /= value.Z;
			W /= value.W;
		}

		//
		// operators
		//

		// Addition

		public static float4 operator +(float4 left, float4 right) => float4(left.X + right.X, left.Y + right.Y, left.Z + right.Z, left.W + right.W);

		public static float4 operator +(float4 value, float scalar) => float4(value.X + scalar, value.Y + scalar, value.Z + scalar, value.W + scalar);
		
		public static float4 operator +(float scalar, float4 value) => float4(scalar + value.X, scalar + value.Y, scalar + value.Z, scalar + value.W);

		public static float4 operator +(float4 value) => value;

		// Subtraction
		
		public static float4 operator -(float4 left, float4 right) => float4(left.X - right.X, left.Y - right.Y, left.Z - right.Z, left.W - right.W);

		public static float4 operator -(float4 value, float scalar) => float4(value.X - scalar, value.Y - scalar, value.Z - scalar, value.W - scalar);

		public static float4 operator -(float scalar, float4 value) => float4(scalar - value.X, scalar - value.Y, scalar - value.Z, scalar - value.W);

		public static float4 operator -(float4 value) => float4(-value.X, -value.Y, -value.Z, -value.W);

		// Multiplication

		public static float4 operator *(float4 left, float4 right) => float4(left.X * right.X, left.Y * right.Y, left.Z * right.Z, left.W * right.W);

		public static float4 operator *(float4 value, float scalar) => float4(value.X * scalar, value.Y * scalar, value.Z * scalar, value.W * scalar);

		public static float4 operator *(float scalar, float4 value) => float4(scalar * value.X, scalar * value.Y, scalar * value.Z, scalar * value.W);

		// Division
		
		public static float4 operator /(float4 left, float4 right) => float4(left.X / right.X, left.Y / right.Y, left.Z / right.Z, left.W / right.W);

		public static float4 operator /(float4 value, float scalar)
		{	
			float inv = 1.0f / scalar;
			return float4(value.X * inv, value.Y * inv, value.Z * inv, value.W * inv);
		}

		public static float4 operator /(float scalar, float4 value) => float4(scalar / value.X, scalar / value.Y, scalar / value.Z, scalar / value.W);

		// Equality

		public static bool operator ==(float4 left, float4 right) => left.X == right.X && left.Y == right.Y && left.Z == right.Z && left.W == right.W;

		public static bool operator !=(float4 left, float4 right) => left.X != right.X || left.Y != right.Y || left.Z != right.Z || left.W != right.W;

		public override void ToString(String strBuffer) => strBuffer.AppendF("X:{0} Y:{1} Z:{2} W:{3}", X, Y, Z, W);

		[Inline]
		public static explicit operator Self(float value) => Self(value);

		[Inline]
#unwarn
		public static explicit operator float[4](float4 value) => *(float[4]*)&value;
	}
}
