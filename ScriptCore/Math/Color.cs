using System.Runtime.InteropServices;

namespace GlitchyEngine.Math;

using static GlitchyEngine.Math.Math;

/// <summary>
/// Represents a color with red, blue, green color channels and alpha.
/// <br/>Each channel is represented by a <see cref="byte"/>
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack=1)]
public struct Color
{
	public static readonly Color AliceBlue = (Color)ColorRGBA.AliceBlue;
    public static readonly Color AntiqueWhite = (Color)ColorRGBA.AntiqueWhite;
    public static readonly Color Aqua = (Color)ColorRGBA.Aqua;
    public static readonly Color Aquamarine = (Color)ColorRGBA.Aquamarine;
    public static readonly Color Azure = (Color)ColorRGBA.Azure;
    public static readonly Color Beige = (Color)ColorRGBA.Beige;
    public static readonly Color Bisque = (Color)ColorRGBA.Bisque;
    public static readonly Color Black = (Color)ColorRGBA.Black;
    public static readonly Color BlanchedAlmond = (Color)ColorRGBA.BlanchedAlmond;
    public static readonly Color Blue = (Color)ColorRGBA.Blue;
    public static readonly Color BlueViolet = (Color)ColorRGBA.BlueViolet;
    public static readonly Color Brown = (Color)ColorRGBA.Brown;
    public static readonly Color BurlyWood = (Color)ColorRGBA.BurlyWood;
    public static readonly Color CadetBlue = (Color)ColorRGBA.CadetBlue;
    public static readonly Color Chartreuse = (Color)ColorRGBA.Chartreuse;
    public static readonly Color Chocolate = (Color)ColorRGBA.Chocolate;
    public static readonly Color Coral = (Color)ColorRGBA.Coral;
    public static readonly Color CornflowerBlue = (Color)ColorRGBA.CornflowerBlue;
    public static readonly Color Cornsilk = (Color)ColorRGBA.Cornsilk;
    public static readonly Color Crimson = (Color)ColorRGBA.Crimson;
    public static readonly Color Cyan = (Color)ColorRGBA.Cyan;
    public static readonly Color DarkBlue = (Color)ColorRGBA.DarkBlue;
    public static readonly Color DarkCyan = (Color)ColorRGBA.DarkCyan;
    public static readonly Color DarkGoldenrod = (Color)ColorRGBA.DarkGoldenrod;
    public static readonly Color DarkGray = (Color)ColorRGBA.DarkGray;
    public static readonly Color DarkGreen = (Color)ColorRGBA.DarkGreen;
    public static readonly Color DarkKhaki = (Color)ColorRGBA.DarkKhaki;
    public static readonly Color DarkMagenta = (Color)ColorRGBA.DarkMagenta;
    public static readonly Color DarkOliveGreen = (Color)ColorRGBA.DarkOliveGreen;
    public static readonly Color DarkOrange = (Color)ColorRGBA.DarkOrange;
    public static readonly Color DarkOrchid = (Color)ColorRGBA.DarkOrchid;
    public static readonly Color DarkRed = (Color)ColorRGBA.DarkRed;
    public static readonly Color DarkSalmon = (Color)ColorRGBA.DarkSalmon;
    public static readonly Color DarkSeaGreen = (Color)ColorRGBA.DarkSeaGreen;
    public static readonly Color DarkSlateBlue = (Color)ColorRGBA.DarkSlateBlue;
    public static readonly Color DarkSlateGray = (Color)ColorRGBA.DarkSlateGray;
    public static readonly Color DarkTurquoise = (Color)ColorRGBA.DarkTurquoise;
    public static readonly Color DarkViolet = (Color)ColorRGBA.DarkViolet;
    public static readonly Color DeepPink = (Color)ColorRGBA.DeepPink;
    public static readonly Color DeepSkyBlue = (Color)ColorRGBA.DeepSkyBlue;
    public static readonly Color DimGray = (Color)ColorRGBA.DimGray;
    public static readonly Color DodgerBlue = (Color)ColorRGBA.DodgerBlue;
    public static readonly Color Firebrick = (Color)ColorRGBA.Firebrick;
    public static readonly Color FloralWhite = (Color)ColorRGBA.FloralWhite;
    public static readonly Color ForestGreen = (Color)ColorRGBA.ForestGreen;
    public static readonly Color Fuchsia = (Color)ColorRGBA.Fuchsia;
    public static readonly Color Gainsboro = (Color)ColorRGBA.Gainsboro;
    public static readonly Color GhostWhite = (Color)ColorRGBA.GhostWhite;
    public static readonly Color Gold = (Color)ColorRGBA.Gold;
    public static readonly Color Goldenrod = (Color)ColorRGBA.Goldenrod;
    public static readonly Color Gray = (Color)ColorRGBA.Gray;
    public static readonly Color Green = (Color)ColorRGBA.Green;
    public static readonly Color GreenYellow = (Color)ColorRGBA.GreenYellow;
    public static readonly Color Honeydew = (Color)ColorRGBA.Honeydew;
    public static readonly Color HotPink = (Color)ColorRGBA.HotPink;
    public static readonly Color IndianRed = (Color)ColorRGBA.IndianRed;
    public static readonly Color Indigo = (Color)ColorRGBA.Indigo;
    public static readonly Color Ivory = (Color)ColorRGBA.Ivory;
    public static readonly Color Khaki = (Color)ColorRGBA.Khaki;
    public static readonly Color Lavender = (Color)ColorRGBA.Lavender;
    public static readonly Color LavenderBlush = (Color)ColorRGBA.LavenderBlush;
    public static readonly Color LawnGreen = (Color)ColorRGBA.LawnGreen;
    public static readonly Color LemonChiffon = (Color)ColorRGBA.LemonChiffon;
    public static readonly Color LightBlue = (Color)ColorRGBA.LightBlue;
    public static readonly Color LightCoral = (Color)ColorRGBA.LightCoral;
    public static readonly Color LightCyan = (Color)ColorRGBA.LightCyan;
    public static readonly Color LightGoldenrodYellow = (Color)ColorRGBA.LightGoldenrodYellow;
    public static readonly Color LightGreen = (Color)ColorRGBA.LightGreen;
    public static readonly Color LightGray = (Color)ColorRGBA.LightGray;
    public static readonly Color LightPink = (Color)ColorRGBA.LightPink;
    public static readonly Color LightSalmon = (Color)ColorRGBA.LightSalmon;
    public static readonly Color LightSeaGreen = (Color)ColorRGBA.LightSeaGreen;
    public static readonly Color LightSkyBlue = (Color)ColorRGBA.LightSkyBlue;
    public static readonly Color LightSlateGray = (Color)ColorRGBA.LightSlateGray;
    public static readonly Color LightSteelBlue = (Color)ColorRGBA.LightSteelBlue;
    public static readonly Color LightYellow = (Color)ColorRGBA.LightYellow;
    public static readonly Color Lime = (Color)ColorRGBA.Lime;
    public static readonly Color LimeGreen = (Color)ColorRGBA.LimeGreen;
    public static readonly Color Linen = (Color)ColorRGBA.Linen;
    public static readonly Color Magenta = (Color)ColorRGBA.Magenta;
    public static readonly Color Maroon = (Color)ColorRGBA.Maroon;
    public static readonly Color MediumAquamarine = (Color)ColorRGBA.MediumAquamarine;
    public static readonly Color MediumBlue = (Color)ColorRGBA.MediumBlue;
    public static readonly Color MediumOrchid = (Color)ColorRGBA.MediumOrchid;
    public static readonly Color MediumPurple = (Color)ColorRGBA.MediumPurple;
    public static readonly Color MediumSeaGreen = (Color)ColorRGBA.MediumSeaGreen;
    public static readonly Color MediumSlateBlue = (Color)ColorRGBA.MediumSlateBlue;
    public static readonly Color MediumSpringGreen = (Color)ColorRGBA.MediumSpringGreen;
    public static readonly Color MediumTurquoise = (Color)ColorRGBA.MediumTurquoise;
    public static readonly Color MediumVioletRed = (Color)ColorRGBA.MediumVioletRed;
    public static readonly Color MidnightBlue = (Color)ColorRGBA.MidnightBlue;
    public static readonly Color MintCream = (Color)ColorRGBA.MintCream;
    public static readonly Color MistyRose = (Color)ColorRGBA.MistyRose;
    public static readonly Color Moccasin = (Color)ColorRGBA.Moccasin;
    public static readonly Color NavajoWhite = (Color)ColorRGBA.NavajoWhite;
    public static readonly Color Navy = (Color)ColorRGBA.Navy;
    public static readonly Color OldLace = (Color)ColorRGBA.OldLace;
    public static readonly Color Olive = (Color)ColorRGBA.Olive;
    public static readonly Color OliveDrab = (Color)ColorRGBA.OliveDrab;
    public static readonly Color Orange = (Color)ColorRGBA.Orange;
    public static readonly Color OrangeRed = (Color)ColorRGBA.OrangeRed;
    public static readonly Color Orchid = (Color)ColorRGBA.Orchid;
    public static readonly Color PaleGoldenrod = (Color)ColorRGBA.PaleGoldenrod;
    public static readonly Color PaleGreen = (Color)ColorRGBA.PaleGreen;
    public static readonly Color PaleTurquoise = (Color)ColorRGBA.PaleTurquoise;
    public static readonly Color PaleVioletRed = (Color)ColorRGBA.PaleVioletRed;
    public static readonly Color PapayaWhip = (Color)ColorRGBA.PapayaWhip;
    public static readonly Color PeachPuff = (Color)ColorRGBA.PeachPuff;
    public static readonly Color Peru = (Color)ColorRGBA.Peru;
    public static readonly Color Pink = (Color)ColorRGBA.Pink;
    public static readonly Color Plum = (Color)ColorRGBA.Plum;
    public static readonly Color PowderBlue = (Color)ColorRGBA.PowderBlue;
    public static readonly Color Purple = (Color)ColorRGBA.Purple;
    public static readonly Color Red = (Color)ColorRGBA.Red;
    public static readonly Color RosyBrown = (Color)ColorRGBA.RosyBrown;
    public static readonly Color RoyalBlue = (Color)ColorRGBA.RoyalBlue;
    public static readonly Color SaddleBrown = (Color)ColorRGBA.SaddleBrown;
    public static readonly Color Salmon = (Color)ColorRGBA.Salmon;
    public static readonly Color SandyBrown = (Color)ColorRGBA.SandyBrown;
    public static readonly Color SeaGreen = (Color)ColorRGBA.SeaGreen;
    public static readonly Color SeaShell = (Color)ColorRGBA.SeaShell;
    public static readonly Color Sienna = (Color)ColorRGBA.Sienna;
    public static readonly Color Silver = (Color)ColorRGBA.Silver;
    public static readonly Color SkyBlue = (Color)ColorRGBA.SkyBlue;
    public static readonly Color SlateBlue = (Color)ColorRGBA.SlateBlue;
    public static readonly Color SlateGray = (Color)ColorRGBA.SlateGray;
    public static readonly Color Snow = (Color)ColorRGBA.Snow;
    public static readonly Color SpringGreen = (Color)ColorRGBA.SpringGreen;
    public static readonly Color SteelBlue = (Color)ColorRGBA.SteelBlue;
    public static readonly Color Tan = (Color)ColorRGBA.Tan;
    public static readonly Color Teal = (Color)ColorRGBA.Teal;
    public static readonly Color Thistle = (Color)ColorRGBA.Thistle;
    public static readonly Color Tomato = (Color)ColorRGBA.Tomato;
    public static readonly Color Transparent = (Color)ColorRGBA.Transparent;
    public static readonly Color Turquoise = (Color)ColorRGBA.Turquoise;
    public static readonly Color Violet = (Color)ColorRGBA.Violet;
    public static readonly Color Wheat = (Color)ColorRGBA.Wheat;
    public static readonly Color White = (Color)ColorRGBA.White;
    public static readonly Color WhiteSmoke = (Color)ColorRGBA.WhiteSmoke;
    public static readonly Color Yellow = (Color)ColorRGBA.Yellow;
    public static readonly Color YellowGreen = (Color)ColorRGBA.YellowGreen;
    
    /// <summary>
    /// The red component of the color.
    /// </summary>
    public byte R;
    
    /// <summary>
    /// The green component of the color.
    /// </summary>
    public byte G;
    
    /// <summary>
    /// The blue component of the color.
    /// </summary>
    public byte B;
    
    /// <summary>
    /// The alpha component of the color.
    /// </summary>
    public byte A;

    /// <summary>
    /// Creates a new instance of <see cref="Color"/> with all components set to 0.
    /// </summary>
    public Color() { }

    /// <summary>
    /// Creates a new instance of <see cref="Color"/> with the specified values.
    /// </summary>
    /// <param name="r">The red component of the color.</param>
    /// <param name="g">The green component of the color.</param>
    /// <param name="b">The blue component of the color.</param>
    /// <param name="a">The alpha component of the color.</param>
    public Color(byte r, byte g, byte b, byte a = 255)
    {
        R = r;
        G = g;
        B = b;
        A = a;
    }
    
    public static explicit operator ColorRGBA(Color color) => new ColorRGBA(color.R / 255.0f, color.G / 255.0f, color.B / 255.0f, color.A / 255.0f);
    public static explicit operator Color(ColorRGBA color) => new Color((byte)(color.R * 255.0f), (byte)(color.G * 255.0f), (byte)(color.B * 255.0f), (byte)(color.A * 255.0f));
}
