#pragma warning disable 4204

using System;
using System.Diagnostics;

namespace GlitchyEngine.Math
{
	/**
	 * A Vector with three components of type int32.
	 */
	[SwizzleVector(3, "Int")]
	public struct Int3 : IHashable
	{
		public const Int3 Zero  = .(0, 0, 0);
		public const Int3 UnitX = .(1, 0, 0);
		public const Int3 UnitY = .(0, 1, 0);
		public const Int3 UnitZ = .(0, 0, 1);
		public const Int3 One   = .(1, 1, 1);

		public int32 X, Y, Z;

		public this() => this = default;

		public this(int32 value)
		{
			X = value;
			Y = value;
			Z = value;
		}
		
		public this(int value)
		{
			X = (.)value;
			Y = (.)value;
			Z = (.)value;
		}

		public this(int32 x, int32 y, int32 z)
		{
			X = x;
			Y = y;
			Z = z;
		}
		
		public this(Int2 xy, int32 z)
		{
			X = xy.X;
			Y = xy.Y;
			Z = z;
		}
		
		public this(int32 x, Int2 yz)
		{
			X = x;
			Y = yz.X;
			Z = yz.Y;
		}

		public this(int x, int y, int z)
		{
			X = (.)x;
			Y = (.)y;
			Z = (.)z;
		}
		
		public this(Int2 xy, int z)
		{
			X = xy.X;
			Y = xy.Y;
			Z = (.)z;
		}
		
		public this(int x, Int2 yz)
		{
			X = (.)x;
			Y = yz.X;
			Z = yz.Y;
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

		public int32 MagnitudeSquared() => X * X + Y * Y + Z * Z;

		public float Magnitude() => Math.Sqrt(X * X + Y * Y + Z * Z);

		public Int3 Abs() => .(Math.Abs(X), Math.Abs(Y), Math.Abs(Z));

		//
		// Assignment operators
		//

		public void operator +=(Int3 value) mut
		{
			X += value.X;
			Y += value.Y;
			Z += value.Z;
		}

		public void operator +=(int32 value) mut
		{
			X += value;
			Y += value;
			Z += value;
		}
		
		public void operator -=(Int3 value) mut
		{
			X -= value.X;
			Y -= value.Y;
			Z -= value.Z;
		}

		public void operator -=(int32 value) mut
		{
			X -= value;
			Y -= value;
			Z -= value;
		}
		
		public void operator *=(Int3 value) mut
		{
			X *= value.X;
			Y *= value.Y;
			Z *= value.Z;
		}

		public void operator *=(int32 value) mut
		{
			X *= value;
			Y *= value;
			Z *= value;
		}
		
		public void operator /=(Int3 value) mut
		{
			X /= value.X;
			Y /= value.Y;
			Z /= value.Z;
		}

		public void operator /=(int32 value) mut
		{
			X /= value;
			Y /= value;
			Z /= value;
		}

		// Operators

		public static Int3 operator +(Int3 value) => value;
		public static Int3 operator +(Int3 left, Int3 right) => .(left.X + right.X, left.Y + right.Y, left.Z + right.Z);
		public static Int3 operator +(Int3 left, int32 right) => .(left.X + right, left.Y + right, left.Z + right);
		public static Int3 operator +(int32 left, Int3 right) => .(left + right.X, left + right.Y, left + right.Z);

		public static Int3 operator -(Int3 value) => .(-value.X, -value.Y, -value.Z);
		public static Int3 operator -(Int3 left, Int3 right) => .(left.X - right.X, left.Y - right.Y, left.Z - right.Z);
		public static Int3 operator -(Int3 left, int32 right) => .(left.X - right, left.Y - right, left.Z- right);
		public static Int3 operator -(int32 left, Int3 right) => .(left - right.X, left - right.Y, left - right.Z);
		
		public static Int3 operator *(Int3 left, Int3 right) => .(left.X * right.X, left.Y * right.Y, left.Z * right.Z);
		public static Int3 operator *(Int3 left, int32 right) => .(left.X * right, left.Y * right, left.Z * right);
		public static Int3 operator *(int32 left, Int3 right) => .(left * right.X, left * right.Y, left * right.Z);
		
		public static Int3 operator /(Int3 left, Int3 right) => .(left.X / right.X, left.Y / right.Y, left.Z / right.Z);
		public static Int3 operator /(Int3 left, int32 right) => .(left.X / right, left.Y / right, left.Z / right);
		public static Int3 operator /(int32 left, Int3 right) => .(left / right.X, left / right.Y, left / right.Z);
		
		public static Int3 operator %(Int3 left, Int3 right) => .(left.X % right.X, left.Y % right.Y, left.Z % right.Z);
		public static Int3 operator %(Int3 left, int32 right) => .(left.X % right, left.Y % right, left.Z % right);
		public static Int3 operator %(int32 left, Int3 right) => .(left % right.X, left % right.Y, left % right.Z);

		public static bool operator ==(Int3 left, Int3 right) => left.X == right.X && left.Y == right.Y && left.Z == right.Z;
		public static bool operator ==(Int3 left, int32 right) => left.X == right && left.Y == right && left.Z == right;
		public static bool operator ==(int32 left, Int3 right) => left == right.X && left == right.Y && left == right.Z;

		public static bool operator !=(Int3 left, Int3 right) => left.X != right.X || left.Y != right.Y || left.Z != right.Z;
		public static bool operator !=(Int3 left, int32 right) => left.X != right || left.Y != right || left.Z != right;
		public static bool operator !=(int32 left, Int3 right) => left != right.X || left != right.Y || left != right.Z;

		public override void ToString(String strBuffer) => strBuffer.AppendF($"X:{X} Y:{Y} Z:{Z}");

		public static explicit operator Vector3(Int3 point) => .(point.X, point.Y, point.Z);

		public static explicit operator Int3(Vector3 point) => .((int32)point.X, (int32)point.Y, (int32)point.Z);

		[Inline]
		public static explicit operator Int2(in Int3 point) => *(Int2*)&point;

		public int GetHashCode()
		{
			return (((X * 39) ^ Y) * 39) ^ Z;
		}
	}
}