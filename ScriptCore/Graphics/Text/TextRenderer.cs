using GlitchyEngine.Core;
using GlitchyEngine.Math;
using GlitchyEngine.Graphics;

namespace GlitchyEngine.Graphics.Text;

/// <summary>
/// Renders text.
/// </summary>
public class TextRenderer : Component
{
    /// <summary>
    /// Gets or sets whether the text is rich text.<br/>
    /// If <see langword="true"/>, the text will be parsed for rich text tags; if <see langword="false"/>, the text will be rendered as plain text.
    /// </summary>
    public bool IsRichText
    {
        get => ScriptGlue.TextRenderer_GetIsRichText(_uuid);
        set => ScriptGlue.TextRenderer_SetIsRichText(_uuid, value);
    }
    
    /// <summary>
    /// Gets or sets the text.
    /// </summary>
    public string Text
    {
        get
        {
            ScriptGlue.TextRenderer_GetText(_uuid, out string text);
            return text;
        }
        set => ScriptGlue.TextRenderer_SetText(_uuid, value);
    }

    public float FontSize
    {
        get
        {
            ScriptGlue.TextRenderer_GetFontSize(_uuid, out float size);
            return size;
        }
        set => ScriptGlue.TextRenderer_SetFontSize(_uuid, value);
    }
    
    /// <summary>
    /// The color that will be used to render the text. This color can be overridden by rich text tags. 
    /// </summary>
    public ColorRGBA Color
    {
        get
        {
            ScriptGlue.TextRenderer_GetColor(_uuid, out ColorRGBA color);
            return color;
        }
        set => ScriptGlue.TextRenderer_SetColor(_uuid, value);
    }
    
    public HorizontalTextAlignment HorizontalAlignment
    {
        get
        {
            ScriptGlue.TextRenderer_GetHorizontalAlignment(_uuid, out HorizontalTextAlignment alignment);
            return alignment;
        }
        set => ScriptGlue.TextRenderer_SetHorizontalAlignment(_uuid, value);
    }

    // TODO: PreparedText component
}
