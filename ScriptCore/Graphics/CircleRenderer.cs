using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine.Graphics;

/// <summary>
/// Component that renders a circle.
/// </summary>
public class CircleRenderer : Component
{
	// TODO: Texture2D Sprite

    /// <summary>
    /// Gets or sets the tint color of the circle.
    /// </summary>
    public ColorRGBA Color
    {
        get
        {
            ScriptGlue.CircleRenderer_GetColor(_uuid, out ColorRGBA color);
            return color;
        }
        set => ScriptGlue.CircleRenderer_SetColor(_uuid, value);
    }

    /// <summary>
    /// Gets or sets the UV transform for the texture. XY are an offset, ZW are scaling
    /// </summary>
    public float4 UvTransform
    {
        get
        {
            ScriptGlue.CircleRenderer_GetUvTransform(_uuid, out float4 uvTransform);
            return uvTransform;
        }
        set => ScriptGlue.CircleRenderer_SetUvTransform(_uuid, value);
    }

    /// <summary>
    /// Gets or sets the inner radius of the torus. 0 means a circle is rendered.
    /// </summary>
    public float InnerRadius
    {
        get
        {
            ScriptGlue.CircleRenderer_GetInnerRadius(_uuid, out float innerRadius);
            return innerRadius;
        }
        set => ScriptGlue.CircleRenderer_SetInnerRadius(_uuid, value);
    }
}
