#pragma warning disable 4204

using System;
using System.Diagnostics;

namespace GlitchyEngine.Math
{
	/**
	 * A Vector with two components of type int32.
	 */
	[SwizzleVector(2, "Int")]
	public struct Int2 : IHashable
	{
		public const Int2 Zero  = .(0, 0);
		public const Int2 UnitX = .(1, 0);
		public const Int2 UnitY = .(0, 1);
		public const Int2 One   = .(1, 1);

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
		
		public Int2 Abs() => .(Math.Abs(X), Math.Abs(Y));

		//
		// Assignment operators
		//

		public void operator +=(Int2 value) mut
		{
			X += value.X;
			Y += value.Y;
		}

		public void operator +=(int32 value) mut
		{
			X += value;
			Y += value;
		}
		
		public void operator -=(Int2 value) mut
		{
			X -= value.X;
			Y -= value.Y;
		}

		public void operator -=(int32 value) mut
		{
			X -= value;
			Y -= value;
		}
		
		public void operator *=(Int2 value) mut
		{
			X *= value.X;
			Y *= value.Y;
		}

		public void operator *=(int32 value) mut
		{
			X *= value;
			Y *= value;
		}
		
		public void operator /=(Int2 value) mut
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

		public static Int2 operator +(Int2 value) => value;
		public static Int2 operator +(Int2 left, Int2 right) => .(left.X + right.X, left.Y + right.Y);
		public static Int2 operator +(Int2 left, int32 right) => .(left.X + right, left.Y + right);
		public static Int2 operator +(int32 left, Int2 right) => .(left + right.X, left + right.Y);

		public static Int2 operator -(Int2 value) => .(-value.X, -value.Y);
		public static Int2 operator -(Int2 left, Int2 right) => .(left.X - right.X, left.Y - right.Y);
		public static Int2 operator -(Int2 left, int32 right) => .(left.X - right, left.Y - right);
		public static Int2 operator -(int32 left, Int2 right) => .(left - right.X, left - right.Y);
		
		public static Int2 operator *(Int2 left, Int2 right) => .(left.X * right.X, left.Y * right.Y);
		public static Int2 operator *(Int2 left, int32 right) => .(left.X * right, left.Y * right);
		public static Int2 operator *(int32 left, Int2 right) => .(left * right.X, left * right.Y);
		
		public static Int2 operator /(Int2 left, Int2 right) => .(left.X / right.X, left.Y / right.Y);
		public static Int2 operator /(Int2 left, int32 right) => .(left.X / right, left.Y / right);
		public static Int2 operator /(int32 left, Int2 right) => .(left / right.X, left / right.Y);
		
		public static Int2 operator %(Int2 left, Int2 right) => .(left.X % right.X, left.Y % right.Y);
		public static Int2 operator %(Int2 left, int32 right) => .(left.X % right, left.Y % right);
		public static Int2 operator %(int32 left, Int2 right) => .(left % right.X, left % right.Y);

		public static bool operator ==(Int2 left, Int2 right) => left.X == right.X && left.Y == right.Y;
		public static bool operator ==(Int2 left, int32 right) => left.X == right && left.Y == right;
		public static bool operator ==(int32 left, Int2 right) => left == right.X && left == right.Y;

		public static bool operator !=(Int2 left, Int2 right) => left.X != right.X || left.Y != right.Y;
		public static bool operator !=(Int2 left, int32 right) => left.X != right || left.Y != right;
		public static bool operator !=(int32 left, Int2 right) => left != right.X || left != right.Y;

		public override void ToString(String strBuffer) => strBuffer.AppendF($"X:{X} Y:{Y}");

		public static explicit operator float2(Int2 point) => .(point.X, point.Y);

		public static explicit operator Int2(float2 point) => .((int32)point.X, (int32)point.Y);

		public int GetHashCode()
		{
			return (X * 39) ^ Y;
		}
	}
}
