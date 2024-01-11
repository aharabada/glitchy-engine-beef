using System;

namespace GlitchyEngine.Editor;

// TODO: Maybe rename, definitely move into different namespace
/* Why?
 * - this attribute also means that the Field is being serialized
 * - Editor-Namespace wont be available for distribution builds of the game
 */
/// <summary>
/// Specifies that the field should be visible in the editor, regardless of it's code visibility (private, protected, etc...)
/// If this attribute is specified, the field will also be serialized.
/// </summary>
[AttributeUsage(AttributeTargets.Field)]
public sealed class ShowInEditorAttribute : Attribute
{
    /// <summary>
    /// The label with which the field will be shown in the editor.
    /// If not specified, the fields name will be used.
    /// </summary>
    public string? DisplayName { get; set; } = null;
}
