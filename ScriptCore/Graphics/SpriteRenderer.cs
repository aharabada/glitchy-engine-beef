using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine.Graphics;

/// <summary>
/// Component that renders a sprite.
/// </summary>
public class SpriteRenderer : Component
{
    // TODO: Texture2D/Sprite

    /// <summary>
    /// Gets or sets the tint color.
    /// </summary>
    public ColorRGBA Color
    {
        get
        {
            ScriptGlue.SpriteRenderer_GetColor(_uuid, out ColorRGBA color);
            return color;
        }
        set => ScriptGlue.SpriteRenderer_SetColor(_uuid, value);
    }

    /// <summary>
    /// Gets or sets the UV-transform.
    /// </summary>
    public UVTransform UVTransform
    {
        get
        {
            ScriptGlue.SpriteRenderer_GetUvTransform(_uuid, out UVTransform uvTransform);
            return uvTransform;
        }
        set => ScriptGlue.SpriteRenderer_SetUvTransform(_uuid, value);
    }

    /// <summary>
    /// Gets or sets the Material of this SpriteRenderer.
    /// </summary>
    public Material Material
    {
        get
        {
            ScriptGlue.SpriteRenderer_GetMaterial(_uuid, out UUID materialHandle);

            return new Material { _uuid = materialHandle };
        }
        set => ScriptGlue.SpriteRenderer_SetMaterial(_uuid, value._uuid);
    }
}
