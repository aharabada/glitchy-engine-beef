#pragma warning disable 4204

using System;
using System.Diagnostics;

namespace GlitchyEngine.Math
{
	/**
	 * A Vector with four components of type int32.
	 */
	[SwizzleVector(4, "Int32_")]
	public struct Int32_4 : IHashable
	{
		public const Int32_4 Zero  = .(0, 0, 0, 0);
		public const Int32_4 UnitX = .(1, 0, 0, 0);
		public const Int32_4 UnitY = .(0, 1, 0, 0);
		public const Int32_4 UnitZ = .(0, 0, 1, 0);
		public const Int32_4 UnitW = .(0, 0, 0, 1);
		public const Int32_4 One   = .(1, 1, 1, 1);

		public int32 X, Y, Z, W;

		public this() => this = default;

		public this(int32 value)
		{
			X = value;
			Y = value;
			Z = value;
			W = value;
		}
		
		public this(int value)
		{
			X = (.)value;
			Y = (.)value;
			Z = (.)value;
			W = (.)value;
		}

		public this(int32 x, int32 y, int32 z, int32 w)
		{
			X = x;
			Y = y;
			Z = z;
			W = w;
		}
		
		public this(Int32_2 xy, int32 z, int32 w)
		{
			X = xy.X;
			Y = xy.Y;
			Z = z;
			W = w;
		}
		
		public this(int32 x, Int32_2 yz, int32 w)
		{
			X = x;
			Y = yz.X;
			Z = yz.Y;
			W = w;
		}
		
		public this(int32 x, int32 y, Int32_2 zw)
		{
			X = x;
			Y = y;
			Z = zw.X;
			W = zw.Y;
		}

		public this(Int32_2 xy, Int32_2 zw)
		{
			X = xy.X;
			Y = xy.Y;
			Z = zw.X;
			W = zw.Y;
		}
		
		public this(Int32_3 xyz, int32 w)
		{
			X = xyz.X;
			Y = xyz.Y;
			Z = xyz.Z;
			W = w;
		}

		public this(int32 x, Int32_3 yzw)
		{
			X = x;
			Y = yzw.X;
			Z = yzw.Y;
			W = yzw.Z;
		}

		public ref int32 this[int index]
		{
			[Inline]
			get
			{
#if DEBUG
				if(index < 0 || index >= 3)
					Internal.ThrowIndexOutOfRange(1);
#endif

				return ref (&X)[index];
			}
		}

		public int32 MagnitudeSquared() => X * X + Y * Y + Z * Z + W * W;

		public float Magnitude() => Math.Sqrt(X * X + Y * Y + Z * Z + W * W);

		public Int32_4 Abs() => .(Math.Abs(X), Math.Abs(Y), Math.Abs(Z), Math.Abs(W));

		//
		// Assignment operators
		//

		public void operator +=(Int32_4 value) mut
		{
			X += value.X;
			Y += value.Y;
			Z += value.Z;
			W += value.W;
		}

		public void operator +=(int32 value) mut
		{
			X += value;
			Y += value;
			Z += value;
			W += value;
		}
		
		public void operator -=(Int32_4 value) mut
		{
			X -= value.X;
			Y -= value.Y;
			Z -= value.Z;
			W -= value.W;
		}

		public void operator -=(int32 value) mut
		{
			X -= value;
			Y -= value;
			Z -= value;
			W -= value;
		}
		
		public void operator *=(Int32_4 value) mut
		{
			X *= value.X;
			Y *= value.Y;
			Z *= value.Z;
			W *= value.W;
		}

		public void operator *=(int32 value) mut
		{
			X *= value;
			Y *= value;
			Z *= value;
			W *= value;
		}
		
		public void operator /=(Int32_4 value) mut
		{
			X /= value.X;
			Y /= value.Y;
			Z /= value.Z;
			W /= value.W;
		}

		public void operator /=(int32 value) mut
		{
			X /= value;
			Y /= value;
			Z /= value;
			W /= value;
		}

		// Operators

		public static Int32_4 operator +(Int32_4 value) => value;
		public static Int32_4 operator +(Int32_4 left, Int32_4 right) => .(left.X + right.X, left.Y + right.Y, left.Z + right.Z, left.W + right.W);
		public static Int32_4 operator +(Int32_4 left, int32 right) => .(left.X + right, left.Y + right, left.Z + right, left.W + right);
		public static Int32_4 operator +(int32 left, Int32_4 right) => .(left + right.X, left + right.Y, left + right.Z, left + right.W);

		public static Int32_4 operator -(Int32_4 value) => .(-value.X, -value.Y, -value.Z, -value.W);
		public static Int32_4 operator -(Int32_4 left, Int32_4 right) => .(left.X - right.X, left.Y - right.Y, left.Z - right.Z, left.W - right.W);
		public static Int32_4 operator -(Int32_4 left, int32 right) => .(left.X - right, left.Y - right, left.Z - right, left.W - right);
		public static Int32_4 operator -(int32 left, Int32_4 right) => .(left - right.X, left - right.Y, left - right.Z, left - right.W);
		
		public static Int32_4 operator *(Int32_4 left, Int32_4 right) => .(left.X * right.X, left.Y * right.Y, left.Z * right.Z, left.W * right.W);
		public static Int32_4 operator *(Int32_4 left, int32 right) => .(left.X * right, left.Y * right, left.Z * right, left.W * right);
		public static Int32_4 operator *(int32 left, Int32_4 right) => .(left * right.X, left * right.Y, left * right.Z, left * right.W);
		
		public static Int32_4 operator /(Int32_4 left, Int32_4 right) => .(left.X / right.X, left.Y / right.Y, left.Z / right.Z, left.W / right.W);
		public static Int32_4 operator /(Int32_4 left, int32 right) => .(left.X / right, left.Y / right, left.Z / right, left.W / right);
		public static Int32_4 operator /(int32 left, Int32_4 right) => .(left / right.X, left / right.Y, left / right.Z, left / right.W);
		
		public static Int32_4 operator %(Int32_4 left, Int32_4 right) => .(left.X % right.X, left.Y % right.Y, left.Z % right.Z, left.W % right.W);
		public static Int32_4 operator %(Int32_4 left, int32 right) => .(left.X % right, left.Y % right, left.Z % right, left.W % right);
		public static Int32_4 operator %(int32 left, Int32_4 right) => .(left % right.X, left % right.Y, left % right.Z, left % right.W);

		public static bool operator ==(Int32_4 left, Int32_4 right) => left.X == right.X && left.Y == right.Y && left.Z == right.Z && left.W == right.W;
		public static bool operator ==(Int32_4 left, int32 right) => left.X == right && left.Y == right && left.Z == right && left.W == right;
		public static bool operator ==(int32 left, Int32_4 right) => left == right.X && left == right.Y && left == right.Z && left == right.W;

		public static bool operator !=(Int32_4 left, Int32_4 right) => left.X != right.X || left.Y != right.Y || left.Z != right.Z || left.W != right.W;
		public static bool operator !=(Int32_4 left, int32 right) => left.X != right || left.Y != right || left.Z != right || left.W != right;
		public static bool operator !=(int32 left, Int32_4 right) => left != right.X || left != right.Y || left != right.Z || left != right.W;

		public override void ToString(String strBuffer) => strBuffer.AppendF($"X:{X} Y:{Y} Z:{Z} W:{W}");

		public static explicit operator Vector4(Int32_4 point) => .(point.X, point.Y, point.Z, point.W);

		public static explicit operator Int32_4(Vector4 point) => .((int32)point.X, (int32)point.Y, (int32)point.Z, (int32)point.W);

		[Inline]
		public static explicit operator Int32_2(in Int32_4 point) => *(Int32_2*)&point;

		[Inline]
		public static explicit operator Int32_3(in Int32_4 point) => *(Int32_3*)&point;

		public int GetHashCode()
		{
			return (((((X * 39) ^ Y) * 39) ^ Z) * 39) ^ W;
		}
	}
}
