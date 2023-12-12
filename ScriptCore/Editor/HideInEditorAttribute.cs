using System;

namespace GlitchyEngine.Editor;

/// <summary>
/// Specifies, that the field should not be visible in the editor.
/// </summary>
[AttributeUsage(AttributeTargets.Field)]
public sealed class HideInEditorAttribute : Attribute
{
}
