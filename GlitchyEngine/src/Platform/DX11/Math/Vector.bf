#if GE_GRAPHICS_DX11

// Disable warning when taking pointer of in-Parameter
#pragma warning disable 4204

using System;
using Bon;

namespace GlitchyEngine.Math
{
	extension float2
	{
		[Inline]
		public static implicit operator DirectX.Math.Vector2(in Self value) => *(DirectX.Math.Vector2*)&value;

		[Inline]
		public static implicit operator Self(in DirectX.Math.Vector2 value) => *(Self*)&value;
	}

	extension float3
	{
		[Inline]
		public static implicit operator DirectX.Math.Vector3(in Self value) => *(DirectX.Math.Vector3*)&value;

		[Inline]
		public static implicit operator Self(in DirectX.Math.Vector3 value) => *(Self*)&value;
	}

	extension float4
	{
		[Inline]
		public static implicit operator DirectX.Math.Vector4(in Self value) => *(DirectX.Math.Vector4*)&value;

		[Inline]
		public static implicit operator Self(in DirectX.Math.Vector4 value) => *(Self*)&value;
	}
}

namespace DirectX
{
	[BonTarget]
	extension Color;

	[BonTarget]
	extension ColorRGB;

	[BonTarget]
	extension ColorRGBA;
}

#endif
