using GlitchyEngine.Core;

namespace GlitchyEngine.Graphics.Text;

/// <summary>
/// The horizontal alignment of text.
/// </summary>
[EngineClass("GlitchyEngine.Renderer.Text.FontRenderer.HorizontalTextAlignment")]
public enum HorizontalTextAlignment : byte
{
    /// <summary>
    /// Aligns the text to the left.
    /// </summary>
    Left,
    /// <summary>
    /// Aligns the text to the right.
    /// </summary>
    Right,
    /// <summary>
    /// Aligns the text in the center.
    /// </summary>
    Center
}
