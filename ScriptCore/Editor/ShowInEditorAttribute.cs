using System;

namespace GlitchyEngine.Editor;

public sealed class ShowInEditorAttribute : Attribute
{
    public string DisplayName { get; set; } = null;

    public ShowInEditorAttribute()
    {}
}