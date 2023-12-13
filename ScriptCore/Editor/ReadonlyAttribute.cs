using System;

namespace GlitchyEngine.Editor;

/// <summary>
/// Specifies, that the field should be readonly, so that it cannot be changed in the editor.<br/>
/// Note, that this only affects the editor. Scripts can still change the values.
/// </summary>
public sealed class ReadonlyAttribute : Attribute
{
}
