using System.Runtime.InteropServices;

namespace GlitchyEngine.Math;

using static GlitchyEngine.Math.Math;

/// <summary>
/// Represents a color with red, blue, green color channels.
/// <br/>Each channel is represented by a <see cref="float"/>
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack=1)]
public struct ColorRGB
{
    public static readonly ColorRGB AliceBlue = (ColorRGB)ColorRGBA.AliceBlue;
    public static readonly ColorRGB AntiqueWhite = (ColorRGB)ColorRGBA.AntiqueWhite;
    public static readonly ColorRGB Aqua = (ColorRGB)ColorRGBA.Aqua;
    public static readonly ColorRGB Aquamarine = (ColorRGB)ColorRGBA.Aquamarine;
    public static readonly ColorRGB Azure = (ColorRGB)ColorRGBA.Azure;
    public static readonly ColorRGB Beige = (ColorRGB)ColorRGBA.Beige;
    public static readonly ColorRGB Bisque = (ColorRGB)ColorRGBA.Bisque;
    public static readonly ColorRGB Black = (ColorRGB)ColorRGBA.Black;
    public static readonly ColorRGB BlanchedAlmond = (ColorRGB)ColorRGBA.BlanchedAlmond;
    public static readonly ColorRGB Blue = (ColorRGB)ColorRGBA.Blue;
    public static readonly ColorRGB BlueViolet = (ColorRGB)ColorRGBA.BlueViolet;
    public static readonly ColorRGB Brown = (ColorRGB)ColorRGBA.Brown;
    public static readonly ColorRGB BurlyWood = (ColorRGB)ColorRGBA.BurlyWood;
    public static readonly ColorRGB CadetBlue = (ColorRGB)ColorRGBA.CadetBlue;
    public static readonly ColorRGB Chartreuse = (ColorRGB)ColorRGBA.Chartreuse;
    public static readonly ColorRGB Chocolate = (ColorRGB)ColorRGBA.Chocolate;
    public static readonly ColorRGB Coral = (ColorRGB)ColorRGBA.Coral;
    public static readonly ColorRGB CornflowerBlue = (ColorRGB)ColorRGBA.CornflowerBlue;
    public static readonly ColorRGB Cornsilk = (ColorRGB)ColorRGBA.Cornsilk;
    public static readonly ColorRGB Crimson = (ColorRGB)ColorRGBA.Crimson;
    public static readonly ColorRGB Cyan = (ColorRGB)ColorRGBA.Cyan;
    public static readonly ColorRGB DarkBlue = (ColorRGB)ColorRGBA.DarkBlue;
    public static readonly ColorRGB DarkCyan = (ColorRGB)ColorRGBA.DarkCyan;
    public static readonly ColorRGB DarkGoldenrod = (ColorRGB)ColorRGBA.DarkGoldenrod;
    public static readonly ColorRGB DarkGray = (ColorRGB)ColorRGBA.DarkGray;
    public static readonly ColorRGB DarkGreen = (ColorRGB)ColorRGBA.DarkGreen;
    public static readonly ColorRGB DarkKhaki = (ColorRGB)ColorRGBA.DarkKhaki;
    public static readonly ColorRGB DarkMagenta = (ColorRGB)ColorRGBA.DarkMagenta;
    public static readonly ColorRGB DarkOliveGreen = (ColorRGB)ColorRGBA.DarkOliveGreen;
    public static readonly ColorRGB DarkOrange = (ColorRGB)ColorRGBA.DarkOrange;
    public static readonly ColorRGB DarkOrchid = (ColorRGB)ColorRGBA.DarkOrchid;
    public static readonly ColorRGB DarkRed = (ColorRGB)ColorRGBA.DarkRed;
    public static readonly ColorRGB DarkSalmon = (ColorRGB)ColorRGBA.DarkSalmon;
    public static readonly ColorRGB DarkSeaGreen = (ColorRGB)ColorRGBA.DarkSeaGreen;
    public static readonly ColorRGB DarkSlateBlue = (ColorRGB)ColorRGBA.DarkSlateBlue;
    public static readonly ColorRGB DarkSlateGray = (ColorRGB)ColorRGBA.DarkSlateGray;
    public static readonly ColorRGB DarkTurquoise = (ColorRGB)ColorRGBA.DarkTurquoise;
    public static readonly ColorRGB DarkViolet = (ColorRGB)ColorRGBA.DarkViolet;
    public static readonly ColorRGB DeepPink = (ColorRGB)ColorRGBA.DeepPink;
    public static readonly ColorRGB DeepSkyBlue = (ColorRGB)ColorRGBA.DeepSkyBlue;
    public static readonly ColorRGB DimGray = (ColorRGB)ColorRGBA.DimGray;
    public static readonly ColorRGB DodgerBlue = (ColorRGB)ColorRGBA.DodgerBlue;
    public static readonly ColorRGB Firebrick = (ColorRGB)ColorRGBA.Firebrick;
    public static readonly ColorRGB FloralWhite = (ColorRGB)ColorRGBA.FloralWhite;
    public static readonly ColorRGB ForestGreen = (ColorRGB)ColorRGBA.ForestGreen;
    public static readonly ColorRGB Fuchsia = (ColorRGB)ColorRGBA.Fuchsia;
    public static readonly ColorRGB Gainsboro = (ColorRGB)ColorRGBA.Gainsboro;
    public static readonly ColorRGB GhostWhite = (ColorRGB)ColorRGBA.GhostWhite;
    public static readonly ColorRGB Gold = (ColorRGB)ColorRGBA.Gold;
    public static readonly ColorRGB Goldenrod = (ColorRGB)ColorRGBA.Goldenrod;
    public static readonly ColorRGB Gray = (ColorRGB)ColorRGBA.Gray;
    public static readonly ColorRGB Green = (ColorRGB)ColorRGBA.Green;
    public static readonly ColorRGB GreenYellow = (ColorRGB)ColorRGBA.GreenYellow;
    public static readonly ColorRGB Honeydew = (ColorRGB)ColorRGBA.Honeydew;
    public static readonly ColorRGB HotPink = (ColorRGB)ColorRGBA.HotPink;
    public static readonly ColorRGB IndianRed = (ColorRGB)ColorRGBA.IndianRed;
    public static readonly ColorRGB Indigo = (ColorRGB)ColorRGBA.Indigo;
    public static readonly ColorRGB Ivory = (ColorRGB)ColorRGBA.Ivory;
    public static readonly ColorRGB Khaki = (ColorRGB)ColorRGBA.Khaki;
    public static readonly ColorRGB Lavender = (ColorRGB)ColorRGBA.Lavender;
    public static readonly ColorRGB LavenderBlush = (ColorRGB)ColorRGBA.LavenderBlush;
    public static readonly ColorRGB LawnGreen = (ColorRGB)ColorRGBA.LawnGreen;
    public static readonly ColorRGB LemonChiffon = (ColorRGB)ColorRGBA.LemonChiffon;
    public static readonly ColorRGB LightBlue = (ColorRGB)ColorRGBA.LightBlue;
    public static readonly ColorRGB LightCoral = (ColorRGB)ColorRGBA.LightCoral;
    public static readonly ColorRGB LightCyan = (ColorRGB)ColorRGBA.LightCyan;
    public static readonly ColorRGB LightGoldenrodYellow = (ColorRGB)ColorRGBA.LightGoldenrodYellow;
    public static readonly ColorRGB LightGreen = (ColorRGB)ColorRGBA.LightGreen;
    public static readonly ColorRGB LightGray = (ColorRGB)ColorRGBA.LightGray;
    public static readonly ColorRGB LightPink = (ColorRGB)ColorRGBA.LightPink;
    public static readonly ColorRGB LightSalmon = (ColorRGB)ColorRGBA.LightSalmon;
    public static readonly ColorRGB LightSeaGreen = (ColorRGB)ColorRGBA.LightSeaGreen;
    public static readonly ColorRGB LightSkyBlue = (ColorRGB)ColorRGBA.LightSkyBlue;
    public static readonly ColorRGB LightSlateGray = (ColorRGB)ColorRGBA.LightSlateGray;
    public static readonly ColorRGB LightSteelBlue = (ColorRGB)ColorRGBA.LightSteelBlue;
    public static readonly ColorRGB LightYellow = (ColorRGB)ColorRGBA.LightYellow;
    public static readonly ColorRGB Lime = (ColorRGB)ColorRGBA.Lime;
    public static readonly ColorRGB LimeGreen = (ColorRGB)ColorRGBA.LimeGreen;
    public static readonly ColorRGB Linen = (ColorRGB)ColorRGBA.Linen;
    public static readonly ColorRGB Magenta = (ColorRGB)ColorRGBA.Magenta;
    public static readonly ColorRGB Maroon = (ColorRGB)ColorRGBA.Maroon;
    public static readonly ColorRGB MediumAquamarine = (ColorRGB)ColorRGBA.MediumAquamarine;
    public static readonly ColorRGB MediumBlue = (ColorRGB)ColorRGBA.MediumBlue;
    public static readonly ColorRGB MediumOrchid = (ColorRGB)ColorRGBA.MediumOrchid;
    public static readonly ColorRGB MediumPurple = (ColorRGB)ColorRGBA.MediumPurple;
    public static readonly ColorRGB MediumSeaGreen = (ColorRGB)ColorRGBA.MediumSeaGreen;
    public static readonly ColorRGB MediumSlateBlue = (ColorRGB)ColorRGBA.MediumSlateBlue;
    public static readonly ColorRGB MediumSpringGreen = (ColorRGB)ColorRGBA.MediumSpringGreen;
    public static readonly ColorRGB MediumTurquoise = (ColorRGB)ColorRGBA.MediumTurquoise;
    public static readonly ColorRGB MediumVioletRed = (ColorRGB)ColorRGBA.MediumVioletRed;
    public static readonly ColorRGB MidnightBlue = (ColorRGB)ColorRGBA.MidnightBlue;
    public static readonly ColorRGB MintCream = (ColorRGB)ColorRGBA.MintCream;
    public static readonly ColorRGB MistyRose = (ColorRGB)ColorRGBA.MistyRose;
    public static readonly ColorRGB Moccasin = (ColorRGB)ColorRGBA.Moccasin;
    public static readonly ColorRGB NavajoWhite = (ColorRGB)ColorRGBA.NavajoWhite;
    public static readonly ColorRGB Navy = (ColorRGB)ColorRGBA.Navy;
    public static readonly ColorRGB OldLace = (ColorRGB)ColorRGBA.OldLace;
    public static readonly ColorRGB Olive = (ColorRGB)ColorRGBA.Olive;
    public static readonly ColorRGB OliveDrab = (ColorRGB)ColorRGBA.OliveDrab;
    public static readonly ColorRGB Orange = (ColorRGB)ColorRGBA.Orange;
    public static readonly ColorRGB OrangeRed = (ColorRGB)ColorRGBA.OrangeRed;
    public static readonly ColorRGB Orchid = (ColorRGB)ColorRGBA.Orchid;
    public static readonly ColorRGB PaleGoldenrod = (ColorRGB)ColorRGBA.PaleGoldenrod;
    public static readonly ColorRGB PaleGreen = (ColorRGB)ColorRGBA.PaleGreen;
    public static readonly ColorRGB PaleTurquoise = (ColorRGB)ColorRGBA.PaleTurquoise;
    public static readonly ColorRGB PaleVioletRed = (ColorRGB)ColorRGBA.PaleVioletRed;
    public static readonly ColorRGB PapayaWhip = (ColorRGB)ColorRGBA.PapayaWhip;
    public static readonly ColorRGB PeachPuff = (ColorRGB)ColorRGBA.PeachPuff;
    public static readonly ColorRGB Peru = (ColorRGB)ColorRGBA.Peru;
    public static readonly ColorRGB Pink = (ColorRGB)ColorRGBA.Pink;
    public static readonly ColorRGB Plum = (ColorRGB)ColorRGBA.Plum;
    public static readonly ColorRGB PowderBlue = (ColorRGB)ColorRGBA.PowderBlue;
    public static readonly ColorRGB Purple = (ColorRGB)ColorRGBA.Purple;
    public static readonly ColorRGB Red = (ColorRGB)ColorRGBA.Red;
    public static readonly ColorRGB RosyBrown = (ColorRGB)ColorRGBA.RosyBrown;
    public static readonly ColorRGB RoyalBlue = (ColorRGB)ColorRGBA.RoyalBlue;
    public static readonly ColorRGB SaddleBrown = (ColorRGB)ColorRGBA.SaddleBrown;
    public static readonly ColorRGB Salmon = (ColorRGB)ColorRGBA.Salmon;
    public static readonly ColorRGB SandyBrown = (ColorRGB)ColorRGBA.SandyBrown;
    public static readonly ColorRGB SeaGreen = (ColorRGB)ColorRGBA.SeaGreen;
    public static readonly ColorRGB SeaShell = (ColorRGB)ColorRGBA.SeaShell;
    public static readonly ColorRGB Sienna = (ColorRGB)ColorRGBA.Sienna;
    public static readonly ColorRGB Silver = (ColorRGB)ColorRGBA.Silver;
    public static readonly ColorRGB SkyBlue = (ColorRGB)ColorRGBA.SkyBlue;
    public static readonly ColorRGB SlateBlue = (ColorRGB)ColorRGBA.SlateBlue;
    public static readonly ColorRGB SlateGray = (ColorRGB)ColorRGBA.SlateGray;
    public static readonly ColorRGB Snow = (ColorRGB)ColorRGBA.Snow;
    public static readonly ColorRGB SpringGreen = (ColorRGB)ColorRGBA.SpringGreen;
    public static readonly ColorRGB SteelBlue = (ColorRGB)ColorRGBA.SteelBlue;
    public static readonly ColorRGB Tan = (ColorRGB)ColorRGBA.Tan;
    public static readonly ColorRGB Teal = (ColorRGB)ColorRGBA.Teal;
    public static readonly ColorRGB Thistle = (ColorRGB)ColorRGBA.Thistle;
    public static readonly ColorRGB Tomato = (ColorRGB)ColorRGBA.Tomato;
    public static readonly ColorRGB Transparent = (ColorRGB)ColorRGBA.Transparent;
    public static readonly ColorRGB Turquoise = (ColorRGB)ColorRGBA.Turquoise;
    public static readonly ColorRGB Violet = (ColorRGB)ColorRGBA.Violet;
    public static readonly ColorRGB Wheat = (ColorRGB)ColorRGBA.Wheat;
    public static readonly ColorRGB White = (ColorRGB)ColorRGBA.White;
    public static readonly ColorRGB WhiteSmoke = (ColorRGB)ColorRGBA.WhiteSmoke;
    public static readonly ColorRGB Yellow = (ColorRGB)ColorRGBA.Yellow;
    public static readonly ColorRGB YellowGreen = (ColorRGB)ColorRGBA.YellowGreen;
    
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
    /// Creates a new instance of <see cref="ColorRGB"/> with all components set to 0.
    /// </summary>
    public ColorRGB() { }

    /// <summary>
    /// Creates a new instance of <see cref="ColorRGB"/> with the specified values.
    /// </summary>
    /// <param name="r">The red component of the color.</param>
    /// <param name="g">The green component of the color.</param>
    /// <param name="b">The blue component of the color.</param>
    public ColorRGB(float r, float g, float b)
    {
        R = r;
        G = g;
        B = b;
    }

    public static explicit operator float3(ColorRGB color) => new float3(color.R, color.G, color.B);
    public static explicit operator ColorRGB(float3 vector) => new ColorRGB(vector.X, vector.Y, vector.Z);
    
    public static explicit operator ColorRGBA(ColorRGB color) => new ColorRGBA(color.R, color.G, color.B, 1.0f);
    public static explicit operator ColorRGB(ColorRGBA color) => new ColorRGB(color.R, color.G, color.B);
    
    /// <summary>
    /// Converts a Color from sRGB color space to Linear color space.
    /// </summary>
    public static ColorRGB SRgbToLinear(ColorRGB sRGB) => new ColorRGB(pow(sRGB.R, ColorRGBA.SrgbToLin), pow(sRGB.G, ColorRGBA.SrgbToLin), pow(sRGB.B, ColorRGBA.SrgbToLin));

    /// <summary>
    /// Converts a Color from linear color space to sRGB color space.
    /// </summary>
    public static ColorRGB LinearToSRGB(ColorRGB linear) => new ColorRGB(pow(linear.R, ColorRGBA.LinToSRGB), pow(linear.G, ColorRGBA.LinToSRGB), pow(linear.B, ColorRGBA.LinToSRGB));
}
