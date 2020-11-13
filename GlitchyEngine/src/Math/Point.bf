using System;

namespace GlitchyEngine.Math
{
	/**
	 * A 2D point represented by two 32bit integers.
	 */
	public struct Point
	{
		public int32 X, Y;

		/**
		 * Creates a new instance of a @Point with both components set to zero.
		 */
		public this() => this = default;

		/**
		 * Creates a new instance of a @Point with both components set to the specified value.
		 * @param value The value for both components.
		 */
		public this(int32 value)
		{
			X = value;
			Y = value;
		}

		/**
		 * Creates a new instance of a @Point.
		 * @param x The value for the x-component.
		 * @param y The value for the y-component.
		 */
		public this(int32 x, int32 y)
		{
			X = x;
			Y = y;
		}

		//
		// Unary Operators
		//

		public static Point operator +(Point value) => value;

		public static Point operator -(Point value) => .(-value.X, -value.Y);
		
		//
		// Binary Operators
		//

		public static Point operator +(Point left, Point right) => .(left.X + right.X, left.Y + right.Y);
		public static Point operator +(int32 left, Point right) => .(left + right.X, left + right.Y);
		public static Point operator +(Point left, int32 right) => .(left.X + right, left.Y + right);

		public static Point operator -(Point left, Point right) => .(left.X - right.X, left.Y - right.Y);
		public static Point operator -(int32 left, Point right) => .(left - right.X, left - right.Y);
		public static Point operator -(Point left, int32 right) => .(left.X - right, left.Y - right);
		
		public static Point operator *(Point left, Point right) => .(left.X * right.X, left.Y * right.Y);
		public static Point operator *(int32 left, Point right) => .(left * right.X, left * right.Y);
		public static Point operator *(Point left, int32 right) => .(left.X * right, left.Y * right);

		public static Point operator /(Point left, Point right) => .(left.X / right.X, left.Y / right.Y);
		public static Point operator /(int32 left, Point right) => .(left / right.X, left / right.Y);
		public static Point operator /(Point left, int32 right) => .(left.X / right, left.Y / right);

		//
		// Assignment Operators
		//

		public void operator +=(Point value) mut
		{
			X += value.X;
			Y += value.Y;
		}

		public void operator +=(int32 value) mut
		{
			X += value;
			Y += value;
		}
		
		public void operator -=(Point value) mut
		{
			X -= value.X;
			Y -= value.Y;
		}

		public void operator -=(int32 value) mut
		{
			X -= value;
			Y -= value;
		}
		
		public void operator *=(Point value) mut
		{
			X *= value.X;
			Y *= value.Y;
		}

		public void operator *=(int32 value) mut
		{
			X *= value;
			Y *= value;
		}
		
		public void operator /=(Point value) mut
		{
			X /= value.X;
			Y /= value.Y;
		}

		public void operator /=(int32 value) mut
		{
			X /= value;
			Y /= value;
		}

		//
		// Equality
		//
		public static bool operator ==(Point left, Point right) => left.X == right.X && left.Y == right.Y;
		public static bool operator !=(Point left, Point right) => left.X != right.X || left.Y != right.Y;

		//
		// Misc
		//
		public override void ToString(String strBuffer) => strBuffer.AppendF("X={0} Y={1}", X, Y);
	}
}
