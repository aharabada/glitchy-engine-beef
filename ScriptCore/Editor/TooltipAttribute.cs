using System;

namespace GlitchyEngine.Editor;

/// <summary>
/// Specifies the tooltip text that will be shown when the name of the field is hovered in the editor.
/// </summary>
public sealed class TooltipAttribute : Attribute
{
    /// <summary>
    /// The tooltip text.
    /// </summary>
    public string Tooltip { get; private set; }
    
    /// <summary>
    /// Initializes a new instance of the <see cref="TooltipAttribute"/>.
    /// </summary>
    /// <param name="tooltip"><inheritdoc cref="Tooltip"/></param>
    public TooltipAttribute(string tooltip)
    {
        Tooltip = tooltip;
    }
}
