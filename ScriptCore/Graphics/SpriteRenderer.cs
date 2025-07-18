using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine.Graphics;

/// <summary>
/// Component that renders a sprite.
/// </summary>
[EngineClass("GlitchyEngine.World.SpriteRendererComponent")]
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
            unsafe
            {
                // TODO: Is this a type we want to have in the engine?
                ScriptGlue.SpriteRenderer_GetUvTransform(_uuid, out float4 uvTransform);
                return *(UVTransform*)&uvTransform;
            }
        }
        set
        {
            unsafe
            {
                ScriptGlue.SpriteRenderer_SetUvTransform(_uuid, *(float4*)&value);   
            }
        }
    }

    /// <summary>
    /// Gets or sets the Material of this SpriteRenderer.
    /// </summary>
    /// <remarks>
    /// If you get the <see cref="Material"/> and it is not yet a runtime-instance,
    /// a new runtime-instance will be created and returned in its place.
    /// </remarks>
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
