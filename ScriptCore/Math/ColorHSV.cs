namespace GlitchyEngine.Math;

/// <summary>
/// Represents a color with hue, saturation and value.
/// </summary>
public struct ColorHSV
{
    /// <summary>
    /// The hue of the color. Range: 0 - 360°
    /// </summary>
    public float H;
    /// <summary>
    /// The saturation of the color. Range: 0 - 1
    /// </summary>
    public float S;
    /// <summary>
    /// The value of the color. Range: 0 - 1
    /// </summary>
    public float V;

    /// <summary>
    /// Creates a new instance of a <see cref="ColorHSV"/> based on the given hue, saturation and value.
    /// </summary>
    /// <param name="h"><inheritdoc cref="H"/></param>
    /// <param name="s"><inheritdoc cref="S"/></param>
    /// <param name="v"><inheritdoc cref="V"/></param>
    public ColorHSV(float h, float s, float v)
    {
        H = h;
        S = s;
        V = v;
    }

    /// <summary>
    /// Creates a new instance of a <see cref="ColorHSV"/> based on the given <see cref="ColorRGB"/>.
    /// </summary>
    /// <param name="colorRGB">The RGB color that is to be converted to an HSV color</param>
    public ColorHSV(ColorRGB colorRGB)
    {
        this = (ColorHSV)colorRGB;
    }

    public static explicit operator ColorRGB(ColorHSV hsv)
    {
        float c = hsv.V * hsv.S;
        float x = c * (1.0f - Math.abs((hsv.H / 60.0f) % 2.0f - 1.0f));

        float m = hsv.V - c;

        ColorRGB rgb = new ColorRGB();

        hsv.H %= 360.0f;

        if (hsv.H < 60.0f)
            rgb = new ColorRGB(c, x, 0);
        else if (hsv.H < 120.0f)
            rgb = new ColorRGB(x, c, 0);
        else if (hsv.H < 180.0f)
            rgb = new ColorRGB(0, c, x);
        else if (hsv.H < 240.0f)
            rgb = new ColorRGB(0, x, c);
        else if (hsv.H < 300.0f)
            rgb = new ColorRGB(x, 0, c);
        else if (hsv.H < 360.0f)
            rgb = new ColorRGB(c, 0, x);

        return new ColorRGB(rgb.R + m, rgb.G + m, rgb.B + m);
    }

    public static explicit operator ColorHSV(ColorRGB rgb)
    {
        float r = rgb.R;
        float g = rgb.G;
        float b = rgb.B;

        float h;
        float s;
        float v;

        float maxChannel = Math.max(r, Math.max(g, b));
        float minChannel = Math.min(r, Math.min(g, b));
        v = maxChannel;

        if (minChannel == maxChannel)
        {
            h = 0.0f;
            s = 0.0f;
        }
        else
        {
            s = (maxChannel - minChannel) / maxChannel;
            float rc = (maxChannel - r) / (maxChannel - minChannel);
            float gc = (maxChannel - g) / (maxChannel - minChannel);
            float bc = (maxChannel - b) / (maxChannel - minChannel);

            if (r == maxChannel)
            {
                h = 0.0f + bc - gc;
            }
            else if (g == maxChannel)
            {
                h = 2.0f + rc - bc;
            }
            else
            {
                h = 4.0f + gc - rc;
            }

            h = (h / 6.0f) % 1.0f;
            h *= 360.0f;
        }

        return new ColorHSV(h, s, v);
    }
}
