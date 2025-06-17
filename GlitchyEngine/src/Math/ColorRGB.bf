using Bon;
using System;

using internal GlitchyEngine.Math;

namespace GlitchyEngine.Math
{
	/// Represents an RGB color.
	[BonTarget, CRepr]
	public struct ColorRGB
	{
		/**
		 * A value representing the color of the red component.
		 * The range of this value is between 0 and 1.
		*/
		public float R;
		/**
		 * A value representing the color of the green component.
		 * The range of this value is between 0 and 1.
		*/
		public float G;
		/**
		 * A value representing the color of the blue component.
		 * The range of this value is between 0 and 1.
		*/
		public float B;

		public this()
		{
			this = default;
		}

		public this(float red, float green, float blue)
		{
			R = red;
			G = green;
			B = blue;
		}

		public this(ColorRGBA color)
		{
			R = color.R;
			G = color.G;
			B = color.B;
		}

		// Converts a Color from sRGB color space to Linear color space.
		public static ColorRGB SRgbToLinear(ColorRGB sRGB) => ColorRGB(Math.Pow(sRGB.R, srgbToLin), Math.Pow(sRGB.G, srgbToLin), Math.Pow(sRGB.B, srgbToLin));

		// Converts a Color from linear color space to sRGB color space.
		public static ColorRGB LinearToSRGB(ColorRGB linear) => ColorRGB(Math.Pow(linear.R, linToSRGB), Math.Pow(linear.G, linToSRGB), Math.Pow(linear.B, linToSRGB));

		[Inline]
#unwarn
		public static explicit operator float3(ColorRGB color) => *(float3*)&color;
		
		[Inline]
#unwarn
		public static explicit operator ColorRGB(float3 color) => *(ColorRGB*)&color;
	}
}
