using System;
using System.Collections.Generic;
using System.Text;

namespace GlitchyEngine.Editor;

/// <summary>
/// Specifies a string that will be shown as the label of the field in the editor.
/// </summary>
[AttributeUsage(AttributeTargets.Field)]
public sealed class LabelAttribute : Attribute
{
    /// <summary>
    /// The label of the field. If <see langword="null"/>, the actual field name will be shown instead of the "prettified" name that is shown for fields without the <see cref="LabelAttribute"/>.
    /// </summary>
    public string? Label { get; private set; }
    
    /// <summary>
    /// Initializes a new instance of the <see cref="RangeAttribute"/> with a minimum, maximum value and optionally a speed.
    /// </summary>
    /// <param name="label"><inheritdoc cref="Label"/></param>
    public LabelAttribute(string? label)
    {
        Label = label;
    }
}
