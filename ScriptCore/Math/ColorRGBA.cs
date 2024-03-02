using System.Runtime.InteropServices;

namespace GlitchyEngine.Math;

using static GlitchyEngine.Math.Math;

/// <summary>
/// Represents a color with red, blue, green color channels and alpha.
/// <br/>Each channel is represented by a <see cref="float"/>
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack=1)]
public struct ColorRGBA
{
    // from DirectXColors.h
	public static readonly ColorRGBA AliceBlue = new( 0.941176534f, 0.972549081f, 1.000000000f, 1.000000000f );
	public static readonly ColorRGBA AntiqueWhite = new( 0.980392218f, 0.921568692f, 0.843137324f, 1.000000000f );
	public static readonly ColorRGBA Aqua = new( 0.000000000f, 1.000000000f, 1.000000000f, 1.000000000f );
	public static readonly ColorRGBA Aquamarine = new( 0.498039246f, 1.000000000f, 0.831372619f, 1.000000000f );
	public static readonly ColorRGBA Azure = new( 0.941176534f, 1.000000000f, 1.000000000f, 1.000000000f );
	public static readonly ColorRGBA Beige = new( 0.960784376f, 0.960784376f, 0.862745166f, 1.000000000f );
	public static readonly ColorRGBA Bisque = new( 1.000000000f, 0.894117713f, 0.768627524f, 1.000000000f );
	public static readonly ColorRGBA Black = new( 0.000000000f, 0.000000000f, 0.000000000f, 1.000000000f );
	public static readonly ColorRGBA BlanchedAlmond = new( 1.000000000f, 0.921568692f, 0.803921640f, 1.000000000f );
	public static readonly ColorRGBA Blue = new( 0.000000000f, 0.000000000f, 1.000000000f, 1.000000000f );
	public static readonly ColorRGBA BlueViolet = new( 0.541176498f, 0.168627456f, 0.886274576f, 1.000000000f );
	public static readonly ColorRGBA Brown = new( 0.647058845f, 0.164705887f, 0.164705887f, 1.000000000f );
	public static readonly ColorRGBA BurlyWood = new( 0.870588303f, 0.721568644f, 0.529411793f, 1.000000000f );
	public static readonly ColorRGBA CadetBlue = new( 0.372549027f, 0.619607866f, 0.627451003f, 1.000000000f );
	public static readonly ColorRGBA Chartreuse = new( 0.498039246f, 1.000000000f, 0.000000000f, 1.000000000f );
	public static readonly ColorRGBA Chocolate = new( 0.823529482f, 0.411764741f, 0.117647067f, 1.000000000f );
	public static readonly ColorRGBA Coral = new( 1.000000000f, 0.498039246f, 0.313725501f, 1.000000000f );
	public static readonly ColorRGBA CornflowerBlue = new( 0.392156899f, 0.584313750f, 0.929411829f, 1.000000000f );
	public static readonly ColorRGBA Cornsilk = new( 1.000000000f, 0.972549081f, 0.862745166f, 1.000000000f );
	public static readonly ColorRGBA Crimson = new( 0.862745166f, 0.078431375f, 0.235294133f, 1.000000000f );
	public static readonly ColorRGBA Cyan = new( 0.000000000f, 1.000000000f, 1.000000000f, 1.000000000f );
	public static readonly ColorRGBA DarkBlue = new( 0.000000000f, 0.000000000f, 0.545098066f, 1.000000000f );
	public static readonly ColorRGBA DarkCyan = new( 0.000000000f, 0.545098066f, 0.545098066f, 1.000000000f );
	public static readonly ColorRGBA DarkGoldenrod = new( 0.721568644f, 0.525490224f, 0.043137256f, 1.000000000f );
	public static readonly ColorRGBA DarkGray = new( 0.662745118f, 0.662745118f, 0.662745118f, 1.000000000f );
	public static readonly ColorRGBA DarkGreen = new( 0.000000000f, 0.392156899f, 0.000000000f, 1.000000000f );
	public static readonly ColorRGBA DarkKhaki = new( 0.741176486f, 0.717647076f, 0.419607878f, 1.000000000f );
	public static readonly ColorRGBA DarkMagenta = new( 0.545098066f, 0.000000000f, 0.545098066f, 1.000000000f );
	public static readonly ColorRGBA DarkOliveGreen = new( 0.333333343f, 0.419607878f, 0.184313729f, 1.000000000f );
	public static readonly ColorRGBA DarkOrange = new( 1.000000000f, 0.549019635f, 0.000000000f, 1.000000000f );
	public static readonly ColorRGBA DarkOrchid = new( 0.600000024f, 0.196078449f, 0.800000072f, 1.000000000f );
	public static readonly ColorRGBA DarkRed = new( 0.545098066f, 0.000000000f, 0.000000000f, 1.000000000f );
	public static readonly ColorRGBA DarkSalmon = new( 0.913725555f, 0.588235319f, 0.478431404f, 1.000000000f );
	public static readonly ColorRGBA DarkSeaGreen = new( 0.560784340f, 0.737254918f, 0.545098066f, 1.000000000f );
	public static readonly ColorRGBA DarkSlateBlue = new( 0.282352954f, 0.239215702f, 0.545098066f, 1.000000000f );
	public static readonly ColorRGBA DarkSlateGray = new( 0.184313729f, 0.309803933f, 0.309803933f, 1.000000000f );
	public static readonly ColorRGBA DarkTurquoise = new( 0.000000000f, 0.807843208f, 0.819607913f, 1.000000000f );
	public static readonly ColorRGBA DarkViolet = new( 0.580392182f, 0.000000000f, 0.827451050f, 1.000000000f );
	public static readonly ColorRGBA DeepPink = new( 1.000000000f, 0.078431375f, 0.576470613f, 1.000000000f );
	public static readonly ColorRGBA DeepSkyBlue = new( 0.000000000f, 0.749019623f, 1.000000000f, 1.000000000f );
	public static readonly ColorRGBA DimGray = new( 0.411764741f, 0.411764741f, 0.411764741f, 1.000000000f );
	public static readonly ColorRGBA DodgerBlue = new( 0.117647067f, 0.564705908f, 1.000000000f, 1.000000000f );
	public static readonly ColorRGBA Firebrick = new( 0.698039234f, 0.133333340f, 0.133333340f, 1.000000000f );
	public static readonly ColorRGBA FloralWhite = new( 1.000000000f, 0.980392218f, 0.941176534f, 1.000000000f );
	public static readonly ColorRGBA ForestGreen = new( 0.133333340f, 0.545098066f, 0.133333340f, 1.000000000f );
	public static readonly ColorRGBA Fuchsia = new( 1.000000000f, 0.000000000f, 1.000000000f, 1.000000000f );
	public static readonly ColorRGBA Gainsboro = new( 0.862745166f, 0.862745166f, 0.862745166f, 1.000000000f );
	public static readonly ColorRGBA GhostWhite = new( 0.972549081f, 0.972549081f, 1.000000000f, 1.000000000f );
	public static readonly ColorRGBA Gold = new( 1.000000000f, 0.843137324f, 0.000000000f, 1.000000000f );
	public static readonly ColorRGBA Goldenrod = new( 0.854902029f, 0.647058845f, 0.125490203f, 1.000000000f );
	public static readonly ColorRGBA Gray = new( 0.501960814f, 0.501960814f, 0.501960814f, 1.000000000f );
	public static readonly ColorRGBA Green = new( 0.000000000f, 0.501960814f, 0.000000000f, 1.000000000f );
	public static readonly ColorRGBA GreenYellow = new( 0.678431392f, 1.000000000f, 0.184313729f, 1.000000000f );
	public static readonly ColorRGBA Honeydew = new( 0.941176534f, 1.000000000f, 0.941176534f, 1.000000000f );
	public static readonly ColorRGBA HotPink = new( 1.000000000f, 0.411764741f, 0.705882370f, 1.000000000f );
	public static readonly ColorRGBA IndianRed = new( 0.803921640f, 0.360784322f, 0.360784322f, 1.000000000f );
	public static readonly ColorRGBA Indigo = new( 0.294117659f, 0.000000000f, 0.509803951f, 1.000000000f );
	public static readonly ColorRGBA Ivory = new( 1.000000000f, 1.000000000f, 0.941176534f, 1.000000000f );
	public static readonly ColorRGBA Khaki = new( 0.941176534f, 0.901960850f, 0.549019635f, 1.000000000f );
	public static readonly ColorRGBA Lavender = new( 0.901960850f, 0.901960850f, 0.980392218f, 1.000000000f );
	public static readonly ColorRGBA LavenderBlush = new( 1.000000000f, 0.941176534f, 0.960784376f, 1.000000000f );
	public static readonly ColorRGBA LawnGreen = new( 0.486274540f, 0.988235354f, 0.000000000f, 1.000000000f );
	public static readonly ColorRGBA LemonChiffon = new( 1.000000000f, 0.980392218f, 0.803921640f, 1.000000000f );
	public static readonly ColorRGBA LightBlue = new( 0.678431392f, 0.847058892f, 0.901960850f, 1.000000000f );
	public static readonly ColorRGBA LightCoral = new( 0.941176534f, 0.501960814f, 0.501960814f, 1.000000000f );
	public static readonly ColorRGBA LightCyan = new( 0.878431439f, 1.000000000f, 1.000000000f, 1.000000000f );
	public static readonly ColorRGBA LightGoldenrodYellow = new( 0.980392218f, 0.980392218f, 0.823529482f, 1.000000000f );
	public static readonly ColorRGBA LightGreen = new( 0.564705908f, 0.933333397f, 0.564705908f, 1.000000000f );
	public static readonly ColorRGBA LightGray = new( 0.827451050f, 0.827451050f, 0.827451050f, 1.000000000f );
	public static readonly ColorRGBA LightPink = new( 1.000000000f, 0.713725507f, 0.756862819f, 1.000000000f );
	public static readonly ColorRGBA LightSalmon = new( 1.000000000f, 0.627451003f, 0.478431404f, 1.000000000f );
	public static readonly ColorRGBA LightSeaGreen = new( 0.125490203f, 0.698039234f, 0.666666687f, 1.000000000f );
	public static readonly ColorRGBA LightSkyBlue = new( 0.529411793f, 0.807843208f, 0.980392218f, 1.000000000f );
	public static readonly ColorRGBA LightSlateGray = new( 0.466666698f, 0.533333361f, 0.600000024f, 1.000000000f );
	public static readonly ColorRGBA LightSteelBlue = new( 0.690196097f, 0.768627524f, 0.870588303f, 1.000000000f );
	public static readonly ColorRGBA LightYellow = new( 1.000000000f, 1.000000000f, 0.878431439f, 1.000000000f );
	public static readonly ColorRGBA Lime = new( 0.000000000f, 1.000000000f, 0.000000000f, 1.000000000f );
	public static readonly ColorRGBA LimeGreen = new( 0.196078449f, 0.803921640f, 0.196078449f, 1.000000000f );
	public static readonly ColorRGBA Linen = new( 0.980392218f, 0.941176534f, 0.901960850f, 1.000000000f );
	public static readonly ColorRGBA Magenta = new( 1.000000000f, 0.000000000f, 1.000000000f, 1.000000000f );
	public static readonly ColorRGBA Maroon = new( 0.501960814f, 0.000000000f, 0.000000000f, 1.000000000f );
	public static readonly ColorRGBA MediumAquamarine = new( 0.400000036f, 0.803921640f, 0.666666687f, 1.000000000f );
	public static readonly ColorRGBA MediumBlue = new( 0.000000000f, 0.000000000f, 0.803921640f, 1.000000000f );
	public static readonly ColorRGBA MediumOrchid = new( 0.729411781f, 0.333333343f, 0.827451050f, 1.000000000f );
	public static readonly ColorRGBA MediumPurple = new( 0.576470613f, 0.439215720f, 0.858823597f, 1.000000000f );
	public static readonly ColorRGBA MediumSeaGreen = new( 0.235294133f, 0.701960802f, 0.443137288f, 1.000000000f );
	public static readonly ColorRGBA MediumSlateBlue = new( 0.482352972f, 0.407843173f, 0.933333397f, 1.000000000f );
	public static readonly ColorRGBA MediumSpringGreen = new( 0.000000000f, 0.980392218f, 0.603921592f, 1.000000000f );
	public static readonly ColorRGBA MediumTurquoise = new( 0.282352954f, 0.819607913f, 0.800000072f, 1.000000000f );
	public static readonly ColorRGBA MediumVioletRed = new( 0.780392230f, 0.082352944f, 0.521568656f, 1.000000000f );
	public static readonly ColorRGBA MidnightBlue = new( 0.098039225f, 0.098039225f, 0.439215720f, 1.000000000f );
	public static readonly ColorRGBA MintCream = new( 0.960784376f, 1.000000000f, 0.980392218f, 1.000000000f );
	public static readonly ColorRGBA MistyRose = new( 1.000000000f, 0.894117713f, 0.882353008f, 1.000000000f );
	public static readonly ColorRGBA Moccasin = new( 1.000000000f, 0.894117713f, 0.709803939f, 1.000000000f );
	public static readonly ColorRGBA NavajoWhite = new( 1.000000000f, 0.870588303f, 0.678431392f, 1.000000000f );
	public static readonly ColorRGBA Navy = new( 0.000000000f, 0.000000000f, 0.501960814f, 1.000000000f );
	public static readonly ColorRGBA OldLace = new( 0.992156923f, 0.960784376f, 0.901960850f, 1.000000000f );
	public static readonly ColorRGBA Olive = new( 0.501960814f, 0.501960814f, 0.000000000f, 1.000000000f );
	public static readonly ColorRGBA OliveDrab = new( 0.419607878f, 0.556862772f, 0.137254909f, 1.000000000f );
	public static readonly ColorRGBA Orange = new( 1.000000000f, 0.647058845f, 0.000000000f, 1.000000000f );
	public static readonly ColorRGBA OrangeRed = new( 1.000000000f, 0.270588249f, 0.000000000f, 1.000000000f );
	public static readonly ColorRGBA Orchid = new( 0.854902029f, 0.439215720f, 0.839215755f, 1.000000000f );
	public static readonly ColorRGBA PaleGoldenrod = new( 0.933333397f, 0.909803987f, 0.666666687f, 1.000000000f );
	public static readonly ColorRGBA PaleGreen = new( 0.596078455f, 0.984313786f, 0.596078455f, 1.000000000f );
	public static readonly ColorRGBA PaleTurquoise = new( 0.686274529f, 0.933333397f, 0.933333397f, 1.000000000f );
	public static readonly ColorRGBA PaleVioletRed = new( 0.858823597f, 0.439215720f, 0.576470613f, 1.000000000f );
	public static readonly ColorRGBA PapayaWhip = new( 1.000000000f, 0.937254965f, 0.835294187f, 1.000000000f );
	public static readonly ColorRGBA PeachPuff = new( 1.000000000f, 0.854902029f, 0.725490212f, 1.000000000f );
	public static readonly ColorRGBA Peru = new( 0.803921640f, 0.521568656f, 0.247058839f, 1.000000000f );
	public static readonly ColorRGBA Pink = new( 1.000000000f, 0.752941251f, 0.796078503f, 1.000000000f );
	public static readonly ColorRGBA Plum = new( 0.866666734f, 0.627451003f, 0.866666734f, 1.000000000f );
	public static readonly ColorRGBA PowderBlue = new( 0.690196097f, 0.878431439f, 0.901960850f, 1.000000000f );
	public static readonly ColorRGBA Purple = new( 0.501960814f, 0.000000000f, 0.501960814f, 1.000000000f );
	public static readonly ColorRGBA Red = new( 1.000000000f, 0.000000000f, 0.000000000f, 1.000000000f );
	public static readonly ColorRGBA RosyBrown = new( 0.737254918f, 0.560784340f, 0.560784340f, 1.000000000f );
	public static readonly ColorRGBA RoyalBlue = new( 0.254901975f, 0.411764741f, 0.882353008f, 1.000000000f );
	public static readonly ColorRGBA SaddleBrown = new( 0.545098066f, 0.270588249f, 0.074509807f, 1.000000000f );
	public static readonly ColorRGBA Salmon = new( 0.980392218f, 0.501960814f, 0.447058856f, 1.000000000f );
	public static readonly ColorRGBA SandyBrown = new( 0.956862807f, 0.643137276f, 0.376470625f, 1.000000000f );
	public static readonly ColorRGBA SeaGreen = new( 0.180392161f, 0.545098066f, 0.341176480f, 1.000000000f );
	public static readonly ColorRGBA SeaShell = new( 1.000000000f, 0.960784376f, 0.933333397f, 1.000000000f );
	public static readonly ColorRGBA Sienna = new( 0.627451003f, 0.321568638f, 0.176470593f, 1.000000000f );
	public static readonly ColorRGBA Silver = new( 0.752941251f, 0.752941251f, 0.752941251f, 1.000000000f );
	public static readonly ColorRGBA SkyBlue = new( 0.529411793f, 0.807843208f, 0.921568692f, 1.000000000f );
	public static readonly ColorRGBA SlateBlue = new( 0.415686309f, 0.352941185f, 0.803921640f, 1.000000000f );
	public static readonly ColorRGBA SlateGray = new( 0.439215720f, 0.501960814f, 0.564705908f, 1.000000000f );
	public static readonly ColorRGBA Snow = new( 1.000000000f, 0.980392218f, 0.980392218f, 1.000000000f );
	public static readonly ColorRGBA SpringGreen = new( 0.000000000f, 1.000000000f, 0.498039246f, 1.000000000f );
	public static readonly ColorRGBA SteelBlue = new( 0.274509817f, 0.509803951f, 0.705882370f, 1.000000000f );
	public static readonly ColorRGBA Tan = new( 0.823529482f, 0.705882370f, 0.549019635f, 1.000000000f );
	public static readonly ColorRGBA Teal = new( 0.000000000f, 0.501960814f, 0.501960814f, 1.000000000f );
	public static readonly ColorRGBA Thistle = new( 0.847058892f, 0.749019623f, 0.847058892f, 1.000000000f );
	public static readonly ColorRGBA Tomato = new( 1.000000000f, 0.388235331f, 0.278431386f, 1.000000000f );
	public static readonly ColorRGBA Transparent = new( 0.000000000f, 0.000000000f, 0.000000000f, 0.000000000f );
	public static readonly ColorRGBA Turquoise = new( 0.250980407f, 0.878431439f, 0.815686345f, 1.000000000f );
	public static readonly ColorRGBA Violet = new( 0.933333397f, 0.509803951f, 0.933333397f, 1.000000000f );
	public static readonly ColorRGBA Wheat = new( 0.960784376f, 0.870588303f, 0.701960802f, 1.000000000f );
	public static readonly ColorRGBA White = new( 1.000000000f, 1.000000000f, 1.000000000f, 1.000000000f );
	public static readonly ColorRGBA WhiteSmoke = new( 0.960784376f, 0.960784376f, 0.960784376f, 1.000000000f );
	public static readonly ColorRGBA Yellow = new( 1.000000000f, 1.000000000f, 0.000000000f, 1.000000000f );
	public static readonly ColorRGBA YellowGreen = new( 0.603921592f, 0.803921640f, 0.196078449f, 1.000000000f );
    
    internal const float SrgbToLin = 2.2f;
    internal const float LinToSRGB = (float)(1.0 / 2.2);

    /// <summary>
    /// The red component of the color.
    /// </summary>
    public float R;
    
    /// <summary>
    /// The green component of the color.
    /// </summary>
    public float G;
    
    /// <summary>
    /// The blue component of the color.
    /// </summary>
    public float B;
    
    /// <summary>
    /// The alpha component of the color.
    /// </summary>
    public float A;

    /// <summary>
    /// Creates a new instance of ColorRGBA with all components set to 0.
    /// </summary>
    public ColorRGBA() { }

    /// <summary>
    /// Creates a new instance of ColorRGBA with the specified values.
    /// </summary>
    /// <param name="r">The red component of the color.</param>
    /// <param name="g">The green component of the color.</param>
    /// <param name="b">The blue component of the color.</param>
    /// <param name="a">The alpha component of the color.</param>
    public ColorRGBA(float r, float g, float b, float a = 1.0f)
    {
        R = r;
        G = g;
        B = b;
        A = a;
    }

    public static explicit operator float4(ColorRGBA color) => new float4(color.R, color.G, color.B, color.A);
    public static explicit operator ColorRGBA(float4 vector) => new ColorRGBA(vector.X, vector.Y, vector.Z, vector.W);
    
    /// <summary>
    /// Converts a Color from sRGB color space to Linear color space.
    /// </summary>
    public static ColorRGBA SRgbToLinear(ColorRGBA sRGB) => new ColorRGBA(pow(sRGB.R, SrgbToLin), pow(sRGB.G, SrgbToLin), pow(sRGB.B, SrgbToLin), sRGB.A);

    /// <summary>
    /// Converts a Color from linear color space to sRGB color space.
    /// </summary>
    public static ColorRGBA LinearToSRGB(ColorRGBA linear) => new ColorRGBA(pow(linear.R, LinToSRGB), pow(linear.G, LinToSRGB), pow(linear.B, LinToSRGB), linear.A);
}
