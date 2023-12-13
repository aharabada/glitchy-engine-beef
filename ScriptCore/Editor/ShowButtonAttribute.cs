
using System;

namespace GlitchyEngine.Editor;

/// <summary>
/// Specifies the visibility of a button.
/// </summary>
public enum ButtonVisibility
{
    /// <summary>
    /// The button will be visible in edit mode.
    /// </summary>
    InEditMode = 1,
    /// <summary>
    /// The button will be visible in play mode.
    /// </summary>
    InPlayMode = 2,
    /// <summary>
    /// The button will always be visible.
    /// </summary>
    Always = InEditMode | InPlayMode
}

/// <summary>
/// Specifies that a button will be shown in the editor that, when clicked, executes the method this attribute is attached to.
/// </summary>
[AttributeUsage(AttributeTargets.Method)]
public sealed class ShowButtonAttribute : Attribute
{
    /// <summary>
    /// The text on the button.
    /// </summary>
    public string ButtonText { get; private set; }

    /// <summary>
    /// Determines whether the button is visible in edit and/or play mode.
    /// </summary>
    public ButtonVisibility Visibility { get; set; } = ButtonVisibility.Always;

    public ShowButtonAttribute(string buttonText)
    {
        ButtonText = buttonText;
    }
}
