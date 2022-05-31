using System;

using internal GlitchyEngine.Math;

namespace GlitchyEngine.Math
{
	static
	{
		internal const float srgbToLin = 2.2f;
		internal const float linToSRGB = (float)(1.0 / 2.2);
	}

	/**
	Represents a four component floating point color
	*/
	[CRepr]
	struct ColorRGBA
	{
		// from DirectXColors.h
		public const ColorRGBA AliceBlue            = .( 0.941176534f, 0.972549081f, 1.000000000f, 1.000000000f );
		public const ColorRGBA AntiqueWhite         = .( 0.980392218f, 0.921568692f, 0.843137324f, 1.000000000f );
		public const ColorRGBA Aqua                 = .( 0.000000000f, 1.000000000f, 1.000000000f, 1.000000000f );
		public const ColorRGBA Aquamarine           = .( 0.498039246f, 1.000000000f, 0.831372619f, 1.000000000f );
		public const ColorRGBA Azure                = .( 0.941176534f, 1.000000000f, 1.000000000f, 1.000000000f );
		public const ColorRGBA Beige                = .( 0.960784376f, 0.960784376f, 0.862745166f, 1.000000000f );
		public const ColorRGBA Bisque               = .( 1.000000000f, 0.894117713f, 0.768627524f, 1.000000000f );
		public const ColorRGBA Black                = .( 0.000000000f, 0.000000000f, 0.000000000f, 1.000000000f );
		public const ColorRGBA BlanchedAlmond       = .( 1.000000000f, 0.921568692f, 0.803921640f, 1.000000000f );
		public const ColorRGBA Blue                 = .( 0.000000000f, 0.000000000f, 1.000000000f, 1.000000000f );
		public const ColorRGBA BlueViolet           = .( 0.541176498f, 0.168627456f, 0.886274576f, 1.000000000f );
		public const ColorRGBA Brown                = .( 0.647058845f, 0.164705887f, 0.164705887f, 1.000000000f );
		public const ColorRGBA BurlyWood            = .( 0.870588303f, 0.721568644f, 0.529411793f, 1.000000000f );
		public const ColorRGBA CadetBlue            = .( 0.372549027f, 0.619607866f, 0.627451003f, 1.000000000f );
		public const ColorRGBA Chartreuse           = .( 0.498039246f, 1.000000000f, 0.000000000f, 1.000000000f );
		public const ColorRGBA Chocolate            = .( 0.823529482f, 0.411764741f, 0.117647067f, 1.000000000f );
		public const ColorRGBA Coral                = .( 1.000000000f, 0.498039246f, 0.313725501f, 1.000000000f );
		public const ColorRGBA CornflowerBlue       = .( 0.392156899f, 0.584313750f, 0.929411829f, 1.000000000f );
		public const ColorRGBA Cornsilk             = .( 1.000000000f, 0.972549081f, 0.862745166f, 1.000000000f );
		public const ColorRGBA Crimson              = .( 0.862745166f, 0.078431375f, 0.235294133f, 1.000000000f );
		public const ColorRGBA Cyan                 = .( 0.000000000f, 1.000000000f, 1.000000000f, 1.000000000f );
		public const ColorRGBA DarkBlue             = .( 0.000000000f, 0.000000000f, 0.545098066f, 1.000000000f );
		public const ColorRGBA DarkCyan             = .( 0.000000000f, 0.545098066f, 0.545098066f, 1.000000000f );
		public const ColorRGBA DarkGoldenrod        = .( 0.721568644f, 0.525490224f, 0.043137256f, 1.000000000f );
		public const ColorRGBA DarkGray             = .( 0.662745118f, 0.662745118f, 0.662745118f, 1.000000000f );
		public const ColorRGBA DarkGreen            = .( 0.000000000f, 0.392156899f, 0.000000000f, 1.000000000f );
		public const ColorRGBA DarkKhaki            = .( 0.741176486f, 0.717647076f, 0.419607878f, 1.000000000f );
		public const ColorRGBA DarkMagenta          = .( 0.545098066f, 0.000000000f, 0.545098066f, 1.000000000f );
		public const ColorRGBA DarkOliveGreen       = .( 0.333333343f, 0.419607878f, 0.184313729f, 1.000000000f );
		public const ColorRGBA DarkOrange           = .( 1.000000000f, 0.549019635f, 0.000000000f, 1.000000000f );
		public const ColorRGBA DarkOrchid           = .( 0.600000024f, 0.196078449f, 0.800000072f, 1.000000000f );
		public const ColorRGBA DarkRed              = .( 0.545098066f, 0.000000000f, 0.000000000f, 1.000000000f );
		public const ColorRGBA DarkSalmon           = .( 0.913725555f, 0.588235319f, 0.478431404f, 1.000000000f );
		public const ColorRGBA DarkSeaGreen         = .( 0.560784340f, 0.737254918f, 0.545098066f, 1.000000000f );
		public const ColorRGBA DarkSlateBlue        = .( 0.282352954f, 0.239215702f, 0.545098066f, 1.000000000f );
		public const ColorRGBA DarkSlateGray        = .( 0.184313729f, 0.309803933f, 0.309803933f, 1.000000000f );
		public const ColorRGBA DarkTurquoise        = .( 0.000000000f, 0.807843208f, 0.819607913f, 1.000000000f );
		public const ColorRGBA DarkViolet           = .( 0.580392182f, 0.000000000f, 0.827451050f, 1.000000000f );
		public const ColorRGBA DeepPink             = .( 1.000000000f, 0.078431375f, 0.576470613f, 1.000000000f );
		public const ColorRGBA DeepSkyBlue          = .( 0.000000000f, 0.749019623f, 1.000000000f, 1.000000000f );
		public const ColorRGBA DimGray              = .( 0.411764741f, 0.411764741f, 0.411764741f, 1.000000000f );
		public const ColorRGBA DodgerBlue           = .( 0.117647067f, 0.564705908f, 1.000000000f, 1.000000000f );
		public const ColorRGBA Firebrick            = .( 0.698039234f, 0.133333340f, 0.133333340f, 1.000000000f );
		public const ColorRGBA FloralWhite          = .( 1.000000000f, 0.980392218f, 0.941176534f, 1.000000000f );
		public const ColorRGBA ForestGreen          = .( 0.133333340f, 0.545098066f, 0.133333340f, 1.000000000f );
		public const ColorRGBA Fuchsia              = .( 1.000000000f, 0.000000000f, 1.000000000f, 1.000000000f );
		public const ColorRGBA Gainsboro            = .( 0.862745166f, 0.862745166f, 0.862745166f, 1.000000000f );
		public const ColorRGBA GhostWhite           = .( 0.972549081f, 0.972549081f, 1.000000000f, 1.000000000f );
		public const ColorRGBA Gold                 = .( 1.000000000f, 0.843137324f, 0.000000000f, 1.000000000f );
		public const ColorRGBA Goldenrod            = .( 0.854902029f, 0.647058845f, 0.125490203f, 1.000000000f );
		public const ColorRGBA Gray                 = .( 0.501960814f, 0.501960814f, 0.501960814f, 1.000000000f );
		public const ColorRGBA Green                = .( 0.000000000f, 0.501960814f, 0.000000000f, 1.000000000f );
		public const ColorRGBA GreenYellow          = .( 0.678431392f, 1.000000000f, 0.184313729f, 1.000000000f );
		public const ColorRGBA Honeydew             = .( 0.941176534f, 1.000000000f, 0.941176534f, 1.000000000f );
		public const ColorRGBA HotPink              = .( 1.000000000f, 0.411764741f, 0.705882370f, 1.000000000f );
		public const ColorRGBA IndianRed            = .( 0.803921640f, 0.360784322f, 0.360784322f, 1.000000000f );
		public const ColorRGBA Indigo               = .( 0.294117659f, 0.000000000f, 0.509803951f, 1.000000000f );
		public const ColorRGBA Ivory                = .( 1.000000000f, 1.000000000f, 0.941176534f, 1.000000000f );
		public const ColorRGBA Khaki                = .( 0.941176534f, 0.901960850f, 0.549019635f, 1.000000000f );
		public const ColorRGBA Lavender             = .( 0.901960850f, 0.901960850f, 0.980392218f, 1.000000000f );
		public const ColorRGBA LavenderBlush        = .( 1.000000000f, 0.941176534f, 0.960784376f, 1.000000000f );
		public const ColorRGBA LawnGreen            = .( 0.486274540f, 0.988235354f, 0.000000000f, 1.000000000f );
		public const ColorRGBA LemonChiffon         = .( 1.000000000f, 0.980392218f, 0.803921640f, 1.000000000f );
		public const ColorRGBA LightBlue            = .( 0.678431392f, 0.847058892f, 0.901960850f, 1.000000000f );
		public const ColorRGBA LightCoral           = .( 0.941176534f, 0.501960814f, 0.501960814f, 1.000000000f );
		public const ColorRGBA LightCyan            = .( 0.878431439f, 1.000000000f, 1.000000000f, 1.000000000f );
		public const ColorRGBA LightGoldenrodYellow = .( 0.980392218f, 0.980392218f, 0.823529482f, 1.000000000f );
		public const ColorRGBA LightGreen           = .( 0.564705908f, 0.933333397f, 0.564705908f, 1.000000000f );
		public const ColorRGBA LightGray            = .( 0.827451050f, 0.827451050f, 0.827451050f, 1.000000000f );
		public const ColorRGBA LightPink            = .( 1.000000000f, 0.713725507f, 0.756862819f, 1.000000000f );
		public const ColorRGBA LightSalmon          = .( 1.000000000f, 0.627451003f, 0.478431404f, 1.000000000f );
		public const ColorRGBA LightSeaGreen        = .( 0.125490203f, 0.698039234f, 0.666666687f, 1.000000000f );
		public const ColorRGBA LightSkyBlue         = .( 0.529411793f, 0.807843208f, 0.980392218f, 1.000000000f );
		public const ColorRGBA LightSlateGray       = .( 0.466666698f, 0.533333361f, 0.600000024f, 1.000000000f );
		public const ColorRGBA LightSteelBlue       = .( 0.690196097f, 0.768627524f, 0.870588303f, 1.000000000f );
		public const ColorRGBA LightYellow          = .( 1.000000000f, 1.000000000f, 0.878431439f, 1.000000000f );
		public const ColorRGBA Lime                 = .( 0.000000000f, 1.000000000f, 0.000000000f, 1.000000000f );
		public const ColorRGBA LimeGreen            = .( 0.196078449f, 0.803921640f, 0.196078449f, 1.000000000f );
		public const ColorRGBA Linen                = .( 0.980392218f, 0.941176534f, 0.901960850f, 1.000000000f );
		public const ColorRGBA Magenta              = .( 1.000000000f, 0.000000000f, 1.000000000f, 1.000000000f );
		public const ColorRGBA Maroon               = .( 0.501960814f, 0.000000000f, 0.000000000f, 1.000000000f );
		public const ColorRGBA MediumAquamarine     = .( 0.400000036f, 0.803921640f, 0.666666687f, 1.000000000f );
		public const ColorRGBA MediumBlue           = .( 0.000000000f, 0.000000000f, 0.803921640f, 1.000000000f );
		public const ColorRGBA MediumOrchid         = .( 0.729411781f, 0.333333343f, 0.827451050f, 1.000000000f );
		public const ColorRGBA MediumPurple         = .( 0.576470613f, 0.439215720f, 0.858823597f, 1.000000000f );
		public const ColorRGBA MediumSeaGreen       = .( 0.235294133f, 0.701960802f, 0.443137288f, 1.000000000f );
		public const ColorRGBA MediumSlateBlue      = .( 0.482352972f, 0.407843173f, 0.933333397f, 1.000000000f );
		public const ColorRGBA MediumSpringGreen    = .( 0.000000000f, 0.980392218f, 0.603921592f, 1.000000000f );
		public const ColorRGBA MediumTurquoise      = .( 0.282352954f, 0.819607913f, 0.800000072f, 1.000000000f );
		public const ColorRGBA MediumVioletRed      = .( 0.780392230f, 0.082352944f, 0.521568656f, 1.000000000f );
		public const ColorRGBA MidnightBlue         = .( 0.098039225f, 0.098039225f, 0.439215720f, 1.000000000f );
		public const ColorRGBA MintCream            = .( 0.960784376f, 1.000000000f, 0.980392218f, 1.000000000f );
		public const ColorRGBA MistyRose            = .( 1.000000000f, 0.894117713f, 0.882353008f, 1.000000000f );
		public const ColorRGBA Moccasin             = .( 1.000000000f, 0.894117713f, 0.709803939f, 1.000000000f );
		public const ColorRGBA NavajoWhite          = .( 1.000000000f, 0.870588303f, 0.678431392f, 1.000000000f );
		public const ColorRGBA Navy                 = .( 0.000000000f, 0.000000000f, 0.501960814f, 1.000000000f );
		public const ColorRGBA OldLace              = .( 0.992156923f, 0.960784376f, 0.901960850f, 1.000000000f );
		public const ColorRGBA Olive                = .( 0.501960814f, 0.501960814f, 0.000000000f, 1.000000000f );
		public const ColorRGBA OliveDrab            = .( 0.419607878f, 0.556862772f, 0.137254909f, 1.000000000f );
		public const ColorRGBA Orange               = .( 1.000000000f, 0.647058845f, 0.000000000f, 1.000000000f );
		public const ColorRGBA OrangeRed            = .( 1.000000000f, 0.270588249f, 0.000000000f, 1.000000000f );
		public const ColorRGBA Orchid               = .( 0.854902029f, 0.439215720f, 0.839215755f, 1.000000000f );
		public const ColorRGBA PaleGoldenrod        = .( 0.933333397f, 0.909803987f, 0.666666687f, 1.000000000f );
		public const ColorRGBA PaleGreen            = .( 0.596078455f, 0.984313786f, 0.596078455f, 1.000000000f );
		public const ColorRGBA PaleTurquoise        = .( 0.686274529f, 0.933333397f, 0.933333397f, 1.000000000f );
		public const ColorRGBA PaleVioletRed        = .( 0.858823597f, 0.439215720f, 0.576470613f, 1.000000000f );
		public const ColorRGBA PapayaWhip           = .( 1.000000000f, 0.937254965f, 0.835294187f, 1.000000000f );
		public const ColorRGBA PeachPuff            = .( 1.000000000f, 0.854902029f, 0.725490212f, 1.000000000f );
		public const ColorRGBA Peru                 = .( 0.803921640f, 0.521568656f, 0.247058839f, 1.000000000f );
		public const ColorRGBA Pink                 = .( 1.000000000f, 0.752941251f, 0.796078503f, 1.000000000f );
		public const ColorRGBA Plum                 = .( 0.866666734f, 0.627451003f, 0.866666734f, 1.000000000f );
		public const ColorRGBA PowderBlue           = .( 0.690196097f, 0.878431439f, 0.901960850f, 1.000000000f );
		public const ColorRGBA Purple               = .( 0.501960814f, 0.000000000f, 0.501960814f, 1.000000000f );
		public const ColorRGBA Red                  = .( 1.000000000f, 0.000000000f, 0.000000000f, 1.000000000f );
		public const ColorRGBA RosyBrown            = .( 0.737254918f, 0.560784340f, 0.560784340f, 1.000000000f );
		public const ColorRGBA RoyalBlue            = .( 0.254901975f, 0.411764741f, 0.882353008f, 1.000000000f );
		public const ColorRGBA SaddleBrown          = .( 0.545098066f, 0.270588249f, 0.074509807f, 1.000000000f );
		public const ColorRGBA Salmon               = .( 0.980392218f, 0.501960814f, 0.447058856f, 1.000000000f );
		public const ColorRGBA SandyBrown           = .( 0.956862807f, 0.643137276f, 0.376470625f, 1.000000000f );
		public const ColorRGBA SeaGreen             = .( 0.180392161f, 0.545098066f, 0.341176480f, 1.000000000f );
		public const ColorRGBA SeaShell             = .( 1.000000000f, 0.960784376f, 0.933333397f, 1.000000000f );
		public const ColorRGBA Sienna               = .( 0.627451003f, 0.321568638f, 0.176470593f, 1.000000000f );
		public const ColorRGBA Silver               = .( 0.752941251f, 0.752941251f, 0.752941251f, 1.000000000f );
		public const ColorRGBA SkyBlue              = .( 0.529411793f, 0.807843208f, 0.921568692f, 1.000000000f );
		public const ColorRGBA SlateBlue            = .( 0.415686309f, 0.352941185f, 0.803921640f, 1.000000000f );
		public const ColorRGBA SlateGray            = .( 0.439215720f, 0.501960814f, 0.564705908f, 1.000000000f );
		public const ColorRGBA Snow                 = .( 1.000000000f, 0.980392218f, 0.980392218f, 1.000000000f );
		public const ColorRGBA SpringGreen          = .( 0.000000000f, 1.000000000f, 0.498039246f, 1.000000000f );
		public const ColorRGBA SteelBlue            = .( 0.274509817f, 0.509803951f, 0.705882370f, 1.000000000f );
		public const ColorRGBA Tan                  = .( 0.823529482f, 0.705882370f, 0.549019635f, 1.000000000f );
		public const ColorRGBA Teal                 = .( 0.000000000f, 0.501960814f, 0.501960814f, 1.000000000f );
		public const ColorRGBA Thistle              = .( 0.847058892f, 0.749019623f, 0.847058892f, 1.000000000f );
		public const ColorRGBA Tomato               = .( 1.000000000f, 0.388235331f, 0.278431386f, 1.000000000f );
		public const ColorRGBA Transparent          = .( 0.000000000f, 0.000000000f, 0.000000000f, 0.000000000f );
		public const ColorRGBA Turquoise            = .( 0.250980407f, 0.878431439f, 0.815686345f, 1.000000000f );
		public const ColorRGBA Violet               = .( 0.933333397f, 0.509803951f, 0.933333397f, 1.000000000f );
		public const ColorRGBA Wheat                = .( 0.960784376f, 0.870588303f, 0.701960802f, 1.000000000f );
		public const ColorRGBA White                = .( 1.000000000f, 1.000000000f, 1.000000000f, 1.000000000f );
		public const ColorRGBA WhiteSmoke           = .( 0.960784376f, 0.960784376f, 0.960784376f, 1.000000000f );
		public const ColorRGBA Yellow               = .( 1.000000000f, 1.000000000f, 0.000000000f, 1.000000000f );
		public const ColorRGBA YellowGreen          = .( 0.603921592f, 0.803921640f, 0.196078449f, 1.000000000f );

		/// The red-component of the color
		public float R;
		/// The green-component of the color
		public float G;
		/// The blue-component of the color
		public float B;
		/// The alpha-component of the color
		public float A;

		/// Creates a new instance of ColorRGBA with all components set to 0.
		public this()
		{
			this = default;
		}
		
		/// Creates a new instance of ColorRGBA with the specified values.
		public this(float r, float g, float b, float a = 1.0f)
		{
			R = r;
			G = g;
			B = b;
			A = a;
		}
		
		/// Creates a new instance of ColorRGBA with the specified values.
		public this(ColorRGB color, float a = 1.0f)
		{
			R = color.R;
			G = color.G;
			B = color.B;
			A = a;
		}

		public ref float this[int index]
		{
			[Unchecked]
			get mut
			{
				return ref (&R)[index];
			}

			[Checked]
			get mut
			{			 
				Runtime.Assert(index < 0 || index > 3);
				return ref (&R)[index];
			}
		}

		[Inline]
		public float* ToPtr() mut
		{
			return &R;
		}

		///
		/// Addition
		///

		public void operator +=(ColorRGBA value) mut
		{
			R += value.R;
			G += value.G;
			B += value.B;
			A += value.A;
		}

		public static ColorRGBA operator +(ColorRGBA left, ColorRGBA right)
		{
			return .(left.R + right.R, left.G + right.G, left.B + right.B, left.A + right.A);
		}
		
		///
		/// Subtraction
		///

		public void operator -=(ColorRGBA value) mut
		{
			R -= value.R;
			G -= value.G;
			B -= value.B;
			A -= value.A;
		}

		public static ColorRGBA operator -(ColorRGBA left, ColorRGBA right)
		{
			return .(left.R - right.R, left.G - right.G, left.B - right.B, left.A - right.A);
		}

		///
		/// Multiplication
		///

		public void operator *=(ColorRGBA value) mut
		{
			R *= value.R;
			G *= value.G;
			B *= value.B;
			A *= value.A;
		}

		public void operator *=(float value) mut
		{
			R *= value;
			G *= value;
			B *= value;
			A *= value;
		}

		public static ColorRGBA operator *(ColorRGBA left, ColorRGBA right)
		{
			return .(left.R * right.R, left.G * right.G, left.B * right.B, left.A * right.A);
		}

		public static ColorRGBA operator *(ColorRGBA left, float right)
		{
			return .(left.R * right, left.G * right, left.B * right, left.A * right);
		}

		public static ColorRGBA operator *(float left, ColorRGBA right)
		{
			return .(left * right.R, left * right.G, left * right.B, left * right.A);
		}

		///
		/// Division
		///

		public void operator /=(float value) mut
		{
			R /= value;
			G /= value;
			B /= value;
			A /= value;
		}

		public static ColorRGBA operator /(ColorRGBA left, float right)
		{
			return .(left.R / right, left.G / right, left.B / right, left.A / right);
		}

		public static ColorRGBA operator /(float left, ColorRGBA right)
		{
			return .(left / right.R, left / right.G, left / right.B, left / right.A);
		}

		public static implicit operator ColorRGB(ColorRGBA color)
		{
			return .(color.R, color.G, color.B);
		}

		// Converts a Color from sRGB color space to Linear color space.
		public static ColorRGBA SRgbToLinear(ColorRGBA sRGB) => ColorRGBA(Math.Pow(sRGB.R, srgbToLin), Math.Pow(sRGB.G, srgbToLin), Math.Pow(sRGB.B, srgbToLin), sRGB.A);

		// Converts a Color from linear color space to sRGB color space.
		public static ColorRGBA LinearToSRGB(ColorRGBA linear) => ColorRGBA(Math.Pow(linear.R, linToSRGB), Math.Pow(linear.G, linToSRGB), Math.Pow(linear.B, linToSRGB), linear.A);
		
		[Inline]
#unwarn
		public static explicit operator Vector4(ColorRGBA color) => *(Vector4*)&color;

		[Inline]
#unwarn
		public static explicit operator ColorRGBA(Vector4 color) => *(ColorRGBA*)&color;
	}
}
