using System;

namespace GlitchyEngine
{
	[CRepr]
	public struct WindowRectangle
	{
		public int32 X;
		public int32 Y;
		public int32 Width;
		public int32 Height;

		public this() => this = default;

		public this(int32 x, int32 y, int32 width, int32 height)
		{
			X = x;
			Y = y;
			Width = width;
			Height = height;
		}
	}
}
