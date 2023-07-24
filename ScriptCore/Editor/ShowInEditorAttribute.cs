using System;

namespace GlitchyEngine.Editor;

// TODO: Maybe rename, definitely move into different namespace
/* Why?
 * - this attribute also means that the Field is being serialized
 * - Editor-Namespace wont be available for distribution builds of the game
 */
[AttributeUsage(AttributeTargets.Field)]
public sealed class ShowInEditorAttribute : Attribute
{
    public string DisplayName { get; set; } = null;

    public ShowInEditorAttribute()
    {}
}