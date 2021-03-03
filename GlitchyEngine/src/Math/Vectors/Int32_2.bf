#pragma warning disable 4204

using System;
using System.Diagnostics;

namespace GlitchyEngine.Math
{
	/**
	 * A Vector with two components of type int32.
	 */
	[SwizzleVector(2, "Int32_")]
	public struct Int32_2 : IHashable
	{
		public const Int32_2 Zero  = .(0, 0);
		public const Int32_2 UnitX = .(1, 0);
		public const Int32_2 UnitY = .(0, 1);
		public const Int32_2 One   = .(1, 1);

		public int32 X, Y;

		public this() => this = default;

		public this(int32 value)
		{
			X = value;
			Y = value;
		}

		public this(int value)
		{
			X = (.)value;
			Y = (.)value;
		}

		public this(int32 x, int32 y)
		{
			X = x;
			Y = y;
		}

		public this(int x, int y)
		{
			X = (.)x;
			Y = (.)y;
		}

		public ref int32 this[int index]
		{
			[Inline]
			get
			{
#if DEBUG
				if(index < 0 || index >= 2)
					Internal.ThrowIndexOutOfRange(1);
#endif

				return ref (&X)[index];
			}
		}

		public int32 MagnitudeSquared() => X * X + Y * Y;

		public float Magnitude() => Math.Sqrt(X * X + Y * Y);
		
		public Int32_2 Abs() => .(Math.Abs(X), Math.Abs(Y));

		//
		// Assignment operators
		//

		public void operator +=(Int32_2 value) mut
		{
			X += value.X;
			Y += value.Y;
		}

		public void operator +=(int32 value) mut
		{
			X += value;
			Y += value;
		}
		
		public void operator -=(Int32_2 value) mut
		{
			X -= value.X;
			Y -= value.Y;
		}

		public void operator -=(int32 value) mut
		{
			X -= value;
			Y -= value;
		}
		
		public void operator *=(Int32_2 value) mut
		{
			X *= value.X;
			Y *= value.Y;
		}

		public void operator *=(int32 value) mut
		{
			X *= value;
			Y *= value;
		}
		
		public void operator /=(Int32_2 value) mut
		{
			X /= value.X;
			Y /= value.Y;
		}

		public void operator /=(int32 value) mut
		{
			X /= value;
			Y /= value;
		}

		// Operators

		public static Int32_2 operator +(Int32_2 value) => value;
		public static Int32_2 operator +(Int32_2 left, Int32_2 right) => .(left.X + right.X, left.Y + right.Y);
		public static Int32_2 operator +(Int32_2 left, int32 right) => .(left.X + right, left.Y + right);
		public static Int32_2 operator +(int32 left, Int32_2 right) => .(left + right.X, left + right.Y);

		public static Int32_2 operator -(Int32_2 value) => .(-value.X, -value.Y);
		public static Int32_2 operator -(Int32_2 left, Int32_2 right) => .(left.X - right.X, left.Y - right.Y);
		public static Int32_2 operator -(Int32_2 left, int32 right) => .(left.X - right, left.Y - right);
		public static Int32_2 operator -(int32 left, Int32_2 right) => .(left - right.X, left - right.Y);
		
		public static Int32_2 operator *(Int32_2 left, Int32_2 right) => .(left.X * right.X, left.Y * right.Y);
		public static Int32_2 operator *(Int32_2 left, int32 right) => .(left.X * right, left.Y * right);
		public static Int32_2 operator *(int32 left, Int32_2 right) => .(left * right.X, left * right.Y);
		
		public static Int32_2 operator /(Int32_2 left, Int32_2 right) => .(left.X / right.X, left.Y / right.Y);
		public static Int32_2 operator /(Int32_2 left, int32 right) => .(left.X / right, left.Y / right);
		public static Int32_2 operator /(int32 left, Int32_2 right) => .(left / right.X, left / right.Y);
		
		public static Int32_2 operator %(Int32_2 left, Int32_2 right) => .(left.X % right.X, left.Y % right.Y);
		public static Int32_2 operator %(Int32_2 left, int32 right) => .(left.X % right, left.Y % right);
		public static Int32_2 operator %(int32 left, Int32_2 right) => .(left % right.X, left % right.Y);

		public static bool operator ==(Int32_2 left, Int32_2 right) => left.X == right.X && left.Y == right.Y;
		public static bool operator ==(Int32_2 left, int32 right) => left.X == right && left.Y == right;
		public static bool operator ==(int32 left, Int32_2 right) => left == right.X && left == right.Y;

		public static bool operator !=(Int32_2 left, Int32_2 right) => left.X != right.X || left.Y != right.Y;
		public static bool operator !=(Int32_2 left, int32 right) => left.X != right || left.Y != right;
		public static bool operator !=(int32 left, Int32_2 right) => left != right.X || left != right.Y;

		public override void ToString(String strBuffer) => strBuffer.AppendF($"X:{X} Y:{Y}");

		public static explicit operator Vector2(Int32_2 point) => .(point.X, point.Y);

		public static explicit operator Int32_2(Vector2 point) => .((int32)point.X, (int32)point.Y);

		public int GetHashCode()
		{
			return (X * 39) ^ Y;
		}
	}
}
