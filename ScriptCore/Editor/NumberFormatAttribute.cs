using System;

namespace GlitchyEngine.Editor;

/// <summary>
/// Specifies a custom number format for the input field in the editor.
/// </summary>
/// <remarks>
/// This attribute is only applicable to numerical fields like <see cref="float"/>, <see cref="int"/>, etc.
/// </remarks>
[AttributeUsage(AttributeTargets.Field)]
public sealed class NumberFormatAttribute : Attribute
{
    /// <summary>
    /// The number format for the input field.
    /// </summary>
    /// <remarks>
    /// This doesn't use C# number formatting, but rather the C-style printf number formatting.
    /// </remarks>
    public string Format { get; private set; }
    
    /// <summary>
    /// Initializes a new instance of the <see cref="NumberFormatAttribute"/> with a custom number format.
    /// </summary>
    /// <param name="format"><inheritdoc cref="Format"/></param>
    public NumberFormatAttribute(string format)
    {
        Format = format;
    }
}
