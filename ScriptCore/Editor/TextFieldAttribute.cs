using System;
using System.Collections.Generic;
using System.Text;

namespace GlitchyEngine.Editor;

public sealed class TextFieldAttribute : Attribute
{
    /// <summary>
    /// If <see langword="true"/> the string field will be shown in a multiline text box.
    /// </summary>
    public bool Multiline { get; set; }

    /// <summary>
    /// The number of lines that the text field has. Only applies if <see cref="Multiline"/> is set to <see langword="true"/>.
    /// It does not affect how many lines of text can be stored in the field. Only how many lines the text field itself has.
    /// </summary>
    public int TextFieldLines { get; set; } = 3;
}
