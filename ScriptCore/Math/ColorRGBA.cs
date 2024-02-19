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
