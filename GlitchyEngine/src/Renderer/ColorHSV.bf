using GlitchyEngine.Math;
using System;

namespace GlitchyEngine.Renderer
{
	struct ColorHSV
	{
		public float H;
		public float S;
		public float V;

		public this(float h, float s, float v)
		{
			H = h;
			S = s;
			V = v;
		}

		public static explicit operator ColorRGB(ColorHSV hsv)
		{
			float c = hsv.V * hsv.S;
			float x = c * (1.0f - Math.Abs((hsv.H / 60.0f) % 2.0f - 1.0f));

			float m = hsv.V - c;

			ColorRGB rgb_ = ?;

			if (hsv.H < 60.0f)
				rgb_ = ColorRGB(c, x, 0);
			else if (hsv.H < 120.0f)
				rgb_ = ColorRGB(x, c, 0);
			else if (hsv.H < 180.0f)
				rgb_ = ColorRGB(0, c, x);
			else if (hsv.H < 240.0f)
				rgb_ = ColorRGB(0, x, c);
			else if (hsv.H < 300.0f)
				rgb_ = ColorRGB(x, 0, c);
			else if (hsv.H < 360.0f)
				rgb_ = ColorRGB(c, 0, x);

			return .(rgb_.Red + m, rgb_.Green + m, rgb_.Blue + m);
		}
	}
}