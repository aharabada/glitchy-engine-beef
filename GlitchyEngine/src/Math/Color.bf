using System;

namespace GlitchyEngine.Math
{
	/// Represents a four component color with 8 bit per channel
	[CRepr]
	public struct Color
	{
		// from DirectXColors.h
		// Todo: We probably loose some precision here... Could init them with the correct value
		public const Color AliceBlue            = .( 0.941176534f, 0.972549081f, 1.000000000f, 1.000000000f );
		public const Color AntiqueWhite         = .( 0.980392218f, 0.921568692f, 0.843137324f, 1.000000000f );
		public const Color Aqua                 = .( 0.000000000f, 1.000000000f, 1.000000000f, 1.000000000f );
		public const Color Aquamarine           = .( 0.498039246f, 1.000000000f, 0.831372619f, 1.000000000f );
		public const Color Azure                = .( 0.941176534f, 1.000000000f, 1.000000000f, 1.000000000f );
		public const Color Beige                = .( 0.960784376f, 0.960784376f, 0.862745166f, 1.000000000f );
		public const Color Bisque               = .( 1.000000000f, 0.894117713f, 0.768627524f, 1.000000000f );
		public const Color Black                = .( 0.000000000f, 0.000000000f, 0.000000000f, 1.000000000f );
		public const Color BlanchedAlmond       = .( 1.000000000f, 0.921568692f, 0.803921640f, 1.000000000f );
		public const Color Blue                 = .( 0.000000000f, 0.000000000f, 1.000000000f, 1.000000000f );
		public const Color BlueViolet           = .( 0.541176498f, 0.168627456f, 0.886274576f, 1.000000000f );
		public const Color Brown                = .( 0.647058845f, 0.164705887f, 0.164705887f, 1.000000000f );
		public const Color BurlyWood            = .( 0.870588303f, 0.721568644f, 0.529411793f, 1.000000000f );
		public const Color CadetBlue            = .( 0.372549027f, 0.619607866f, 0.627451003f, 1.000000000f );
		public const Color Chartreuse           = .( 0.498039246f, 1.000000000f, 0.000000000f, 1.000000000f );
		public const Color Chocolate            = .( 0.823529482f, 0.411764741f, 0.117647067f, 1.000000000f );
		public const Color Coral                = .( 1.000000000f, 0.498039246f, 0.313725501f, 1.000000000f );
		public const Color CornflowerBlue       = .( 0.392156899f, 0.584313750f, 0.929411829f, 1.000000000f );
		public const Color Cornsilk             = .( 1.000000000f, 0.972549081f, 0.862745166f, 1.000000000f );
		public const Color Crimson              = .( 0.862745166f, 0.078431375f, 0.235294133f, 1.000000000f );
		public const Color Cyan                 = .( 0.000000000f, 1.000000000f, 1.000000000f, 1.000000000f );
		public const Color DarkBlue             = .( 0.000000000f, 0.000000000f, 0.545098066f, 1.000000000f );
		public const Color DarkCyan             = .( 0.000000000f, 0.545098066f, 0.545098066f, 1.000000000f );
		public const Color DarkGoldenrod        = .( 0.721568644f, 0.525490224f, 0.043137256f, 1.000000000f );
		public const Color DarkGray             = .( 0.662745118f, 0.662745118f, 0.662745118f, 1.000000000f );
		public const Color DarkGreen            = .( 0.000000000f, 0.392156899f, 0.000000000f, 1.000000000f );
		public const Color DarkKhaki            = .( 0.741176486f, 0.717647076f, 0.419607878f, 1.000000000f );
		public const Color DarkMagenta          = .( 0.545098066f, 0.000000000f, 0.545098066f, 1.000000000f );
		public const Color DarkOliveGreen       = .( 0.333333343f, 0.419607878f, 0.184313729f, 1.000000000f );
		public const Color DarkOrange           = .( 1.000000000f, 0.549019635f, 0.000000000f, 1.000000000f );
		public const Color DarkOrchid           = .( 0.600000024f, 0.196078449f, 0.800000072f, 1.000000000f );
		public const Color DarkRed              = .( 0.545098066f, 0.000000000f, 0.000000000f, 1.000000000f );
		public const Color DarkSalmon           = .( 0.913725555f, 0.588235319f, 0.478431404f, 1.000000000f );
		public const Color DarkSeaGreen         = .( 0.560784340f, 0.737254918f, 0.545098066f, 1.000000000f );
		public const Color DarkSlateBlue        = .( 0.282352954f, 0.239215702f, 0.545098066f, 1.000000000f );
		public const Color DarkSlateGray        = .( 0.184313729f, 0.309803933f, 0.309803933f, 1.000000000f );
		public const Color DarkTurquoise        = .( 0.000000000f, 0.807843208f, 0.819607913f, 1.000000000f );
		public const Color DarkViolet           = .( 0.580392182f, 0.000000000f, 0.827451050f, 1.000000000f );
		public const Color DeepPink             = .( 1.000000000f, 0.078431375f, 0.576470613f, 1.000000000f );
		public const Color DeepSkyBlue          = .( 0.000000000f, 0.749019623f, 1.000000000f, 1.000000000f );
		public const Color DimGray              = .( 0.411764741f, 0.411764741f, 0.411764741f, 1.000000000f );
		public const Color DodgerBlue           = .( 0.117647067f, 0.564705908f, 1.000000000f, 1.000000000f );
		public const Color Firebrick            = .( 0.698039234f, 0.133333340f, 0.133333340f, 1.000000000f );
		public const Color FloralWhite          = .( 1.000000000f, 0.980392218f, 0.941176534f, 1.000000000f );
		public const Color ForestGreen          = .( 0.133333340f, 0.545098066f, 0.133333340f, 1.000000000f );
		public const Color Fuchsia              = .( 1.000000000f, 0.000000000f, 1.000000000f, 1.000000000f );
		public const Color Gainsboro            = .( 0.862745166f, 0.862745166f, 0.862745166f, 1.000000000f );
		public const Color GhostWhite           = .( 0.972549081f, 0.972549081f, 1.000000000f, 1.000000000f );
		public const Color Gold                 = .( 1.000000000f, 0.843137324f, 0.000000000f, 1.000000000f );
		public const Color Goldenrod            = .( 0.854902029f, 0.647058845f, 0.125490203f, 1.000000000f );
		public const Color Gray                 = .( 0.501960814f, 0.501960814f, 0.501960814f, 1.000000000f );
		public const Color Green                = .( 0.000000000f, 0.501960814f, 0.000000000f, 1.000000000f );
		public const Color GreenYellow          = .( 0.678431392f, 1.000000000f, 0.184313729f, 1.000000000f );
		public const Color Honeydew             = .( 0.941176534f, 1.000000000f, 0.941176534f, 1.000000000f );
		public const Color HotPink              = .( 1.000000000f, 0.411764741f, 0.705882370f, 1.000000000f );
		public const Color IndianRed            = .( 0.803921640f, 0.360784322f, 0.360784322f, 1.000000000f );
		public const Color Indigo               = .( 0.294117659f, 0.000000000f, 0.509803951f, 1.000000000f );
		public const Color Ivory                = .( 1.000000000f, 1.000000000f, 0.941176534f, 1.000000000f );
		public const Color Khaki                = .( 0.941176534f, 0.901960850f, 0.549019635f, 1.000000000f );
		public const Color Lavender             = .( 0.901960850f, 0.901960850f, 0.980392218f, 1.000000000f );
		public const Color LavenderBlush        = .( 1.000000000f, 0.941176534f, 0.960784376f, 1.000000000f );
		public const Color LawnGreen            = .( 0.486274540f, 0.988235354f, 0.000000000f, 1.000000000f );
		public const Color LemonChiffon         = .( 1.000000000f, 0.980392218f, 0.803921640f, 1.000000000f );
		public const Color LightBlue            = .( 0.678431392f, 0.847058892f, 0.901960850f, 1.000000000f );
		public const Color LightCoral           = .( 0.941176534f, 0.501960814f, 0.501960814f, 1.000000000f );
		public const Color LightCyan            = .( 0.878431439f, 1.000000000f, 1.000000000f, 1.000000000f );
		public const Color LightGoldenrodYellow = .( 0.980392218f, 0.980392218f, 0.823529482f, 1.000000000f );
		public const Color LightGreen           = .( 0.564705908f, 0.933333397f, 0.564705908f, 1.000000000f );
		public const Color LightGray            = .( 0.827451050f, 0.827451050f, 0.827451050f, 1.000000000f );
		public const Color LightPink            = .( 1.000000000f, 0.713725507f, 0.756862819f, 1.000000000f );
		public const Color LightSalmon          = .( 1.000000000f, 0.627451003f, 0.478431404f, 1.000000000f );
		public const Color LightSeaGreen        = .( 0.125490203f, 0.698039234f, 0.666666687f, 1.000000000f );
		public const Color LightSkyBlue         = .( 0.529411793f, 0.807843208f, 0.980392218f, 1.000000000f );
		public const Color LightSlateGray       = .( 0.466666698f, 0.533333361f, 0.600000024f, 1.000000000f );
		public const Color LightSteelBlue       = .( 0.690196097f, 0.768627524f, 0.870588303f, 1.000000000f );
		public const Color LightYellow          = .( 1.000000000f, 1.000000000f, 0.878431439f, 1.000000000f );
		public const Color Lime                 = .( 0.000000000f, 1.000000000f, 0.000000000f, 1.000000000f );
		public const Color LimeGreen            = .( 0.196078449f, 0.803921640f, 0.196078449f, 1.000000000f );
		public const Color Linen                = .( 0.980392218f, 0.941176534f, 0.901960850f, 1.000000000f );
		public const Color Magenta              = .( 1.000000000f, 0.000000000f, 1.000000000f, 1.000000000f );
		public const Color Maroon               = .( 0.501960814f, 0.000000000f, 0.000000000f, 1.000000000f );
		public const Color MediumAquamarine     = .( 0.400000036f, 0.803921640f, 0.666666687f, 1.000000000f );
		public const Color MediumBlue           = .( 0.000000000f, 0.000000000f, 0.803921640f, 1.000000000f );
		public const Color MediumOrchid         = .( 0.729411781f, 0.333333343f, 0.827451050f, 1.000000000f );
		public const Color MediumPurple         = .( 0.576470613f, 0.439215720f, 0.858823597f, 1.000000000f );
		public const Color MediumSeaGreen       = .( 0.235294133f, 0.701960802f, 0.443137288f, 1.000000000f );
		public const Color MediumSlateBlue      = .( 0.482352972f, 0.407843173f, 0.933333397f, 1.000000000f );
		public const Color MediumSpringGreen    = .( 0.000000000f, 0.980392218f, 0.603921592f, 1.000000000f );
		public const Color MediumTurquoise      = .( 0.282352954f, 0.819607913f, 0.800000072f, 1.000000000f );
		public const Color MediumVioletRed      = .( 0.780392230f, 0.082352944f, 0.521568656f, 1.000000000f );
		public const Color MidnightBlue         = .( 0.098039225f, 0.098039225f, 0.439215720f, 1.000000000f );
		public const Color MintCream            = .( 0.960784376f, 1.000000000f, 0.980392218f, 1.000000000f );
		public const Color MistyRose            = .( 1.000000000f, 0.894117713f, 0.882353008f, 1.000000000f );
		public const Color Moccasin             = .( 1.000000000f, 0.894117713f, 0.709803939f, 1.000000000f );
		public const Color NavajoWhite          = .( 1.000000000f, 0.870588303f, 0.678431392f, 1.000000000f );
		public const Color Navy                 = .( 0.000000000f, 0.000000000f, 0.501960814f, 1.000000000f );
		public const Color OldLace              = .( 0.992156923f, 0.960784376f, 0.901960850f, 1.000000000f );
		public const Color Olive                = .( 0.501960814f, 0.501960814f, 0.000000000f, 1.000000000f );
		public const Color OliveDrab            = .( 0.419607878f, 0.556862772f, 0.137254909f, 1.000000000f );
		public const Color Orange               = .( 1.000000000f, 0.647058845f, 0.000000000f, 1.000000000f );
		public const Color OrangeRed            = .( 1.000000000f, 0.270588249f, 0.000000000f, 1.000000000f );
		public const Color Orchid               = .( 0.854902029f, 0.439215720f, 0.839215755f, 1.000000000f );
		public const Color PaleGoldenrod        = .( 0.933333397f, 0.909803987f, 0.666666687f, 1.000000000f );
		public const Color PaleGreen            = .( 0.596078455f, 0.984313786f, 0.596078455f, 1.000000000f );
		public const Color PaleTurquoise        = .( 0.686274529f, 0.933333397f, 0.933333397f, 1.000000000f );
		public const Color PaleVioletRed        = .( 0.858823597f, 0.439215720f, 0.576470613f, 1.000000000f );
		public const Color PapayaWhip           = .( 1.000000000f, 0.937254965f, 0.835294187f, 1.000000000f );
		public const Color PeachPuff            = .( 1.000000000f, 0.854902029f, 0.725490212f, 1.000000000f );
		public const Color Peru                 = .( 0.803921640f, 0.521568656f, 0.247058839f, 1.000000000f );
		public const Color Pink                 = .( 1.000000000f, 0.752941251f, 0.796078503f, 1.000000000f );
		public const Color Plum                 = .( 0.866666734f, 0.627451003f, 0.866666734f, 1.000000000f );
		public const Color PowderBlue           = .( 0.690196097f, 0.878431439f, 0.901960850f, 1.000000000f );
		public const Color Purple               = .( 0.501960814f, 0.000000000f, 0.501960814f, 1.000000000f );
		public const Color Red                  = .( 1.000000000f, 0.000000000f, 0.000000000f, 1.000000000f );
		public const Color RosyBrown            = .( 0.737254918f, 0.560784340f, 0.560784340f, 1.000000000f );
		public const Color RoyalBlue            = .( 0.254901975f, 0.411764741f, 0.882353008f, 1.000000000f );
		public const Color SaddleBrown          = .( 0.545098066f, 0.270588249f, 0.074509807f, 1.000000000f );
		public const Color Salmon               = .( 0.980392218f, 0.501960814f, 0.447058856f, 1.000000000f );
		public const Color SandyBrown           = .( 0.956862807f, 0.643137276f, 0.376470625f, 1.000000000f );
		public const Color SeaGreen             = .( 0.180392161f, 0.545098066f, 0.341176480f, 1.000000000f );
		public const Color SeaShell             = .( 1.000000000f, 0.960784376f, 0.933333397f, 1.000000000f );
		public const Color Sienna               = .( 0.627451003f, 0.321568638f, 0.176470593f, 1.000000000f );
		public const Color Silver               = .( 0.752941251f, 0.752941251f, 0.752941251f, 1.000000000f );
		public const Color SkyBlue              = .( 0.529411793f, 0.807843208f, 0.921568692f, 1.000000000f );
		public const Color SlateBlue            = .( 0.415686309f, 0.352941185f, 0.803921640f, 1.000000000f );
		public const Color SlateGray            = .( 0.439215720f, 0.501960814f, 0.564705908f, 1.000000000f );
		public const Color Snow                 = .( 1.000000000f, 0.980392218f, 0.980392218f, 1.000000000f );
		public const Color SpringGreen          = .( 0.000000000f, 1.000000000f, 0.498039246f, 1.000000000f );
		public const Color SteelBlue            = .( 0.274509817f, 0.509803951f, 0.705882370f, 1.000000000f );
		public const Color Tan                  = .( 0.823529482f, 0.705882370f, 0.549019635f, 1.000000000f );
		public const Color Teal                 = .( 0.000000000f, 0.501960814f, 0.501960814f, 1.000000000f );
		public const Color Thistle              = .( 0.847058892f, 0.749019623f, 0.847058892f, 1.000000000f );
		public const Color Tomato               = .( 1.000000000f, 0.388235331f, 0.278431386f, 1.000000000f );
		public const Color Transparent          = .( 0.000000000f, 0.000000000f, 0.000000000f, 0.000000000f );
		public const Color Turquoise            = .( 0.250980407f, 0.878431439f, 0.815686345f, 1.000000000f );
		public const Color Violet               = .( 0.933333397f, 0.509803951f, 0.933333397f, 1.000000000f );
		public const Color Wheat                = .( 0.960784376f, 0.870588303f, 0.701960802f, 1.000000000f );
		public const Color White                = .( 1.000000000f, 1.000000000f, 1.000000000f, 1.000000000f );
		public const Color WhiteSmoke           = .( 0.960784376f, 0.960784376f, 0.960784376f, 1.000000000f );
		public const Color Yellow               = .( 1.000000000f, 1.000000000f, 0.000000000f, 1.000000000f );
		public const Color YellowGreen          = .( 0.603921592f, 0.803921640f, 0.196078449f, 1.000000000f );

		/// The red-component of the color
		public uint8 R;
		/// The green-component of the color
		public uint8 G;
		/// The blue-component of the color
		public uint8 B;
		/// The alpha-component of the color
		public uint8 A;

		/// Creates a new instance of Color with all components set to 0.
		public this()
		{
			this = default;
		}
		
		/// Creates a new instance of Color with the RGB-values set to the specified values and alpha set to 255.
		public this(uint8 r, uint8 g, uint8 b)
		{
			R = r;
			G = g;
			B = b;
			A = 255;
		}

		/// Creates a new instance of Color with the RGB-values set to the specified values and alpha set to 255.
		public this(float r, float g, float b) : this(r, g, b, 1.0f) {	}

		/// Creates a new instance of Color with the specified values.
		public this(uint8 r, uint8 g, uint8 b, uint8 a)
		{
			R = r;
			G = g;
			B = b;
			A = a;
		}

		const float f = Math.Clamp(12.0f, uint8.MinValue, uint8.MaxValue);

		/// Creates a new instance of Color with the specified values.
		public this(float r, float g, float b, float a)
		{
			R = (uint8)(int)Math.Clamp(r * 255.0f, uint8.MinValue, uint8.MaxValue);
			G = (uint8)(int)Math.Clamp(g * 255.0f, uint8.MinValue, uint8.MaxValue);
			B = (uint8)(int)Math.Clamp(b * 255.0f, uint8.MinValue, uint8.MaxValue);
			A = (uint8)(int)Math.Clamp(a * 255.0f, uint8.MinValue, uint8.MaxValue);
		}

		public ref uint8 this[int index]
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
		public uint8* ToPtr() mut
		{
			return &R;
		}

		// Todo: mathematical operations

		public static explicit operator Color(ColorRGBA col)
		{
			return .(col.R, col.G, col.B, col.A);
		}

		public static explicit operator ColorRGBA(Color col)
		{
			return .(col.R / 255.0f, col.G / 255.0f, col.B / 255.0f, col.A / 255.0f);
		}
	}
}
