#if GE_GRAPHICS_DX11

using System;

namespace GlitchyEngine.Math
{
	extension ColorRGBA
	{
		[Inline]
#unwarn
		public static implicit operator DirectX.ColorRGBA(ColorRGBA self) => *(DirectX.ColorRGBA*)&self;
	}

	extension ColorRGB
	{
		[Inline]
#unwarn
		public static implicit operator DirectX.ColorRGB(ColorRGB self) => *(DirectX.ColorRGB*)&self;
	}

	extension Color
	{
		[Inline]
#unwarn
		public static implicit operator DirectX.Color(Color self) => *(DirectX.Color*)&self;
	}
}

#endif
