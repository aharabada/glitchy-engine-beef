using System;
using System.Collections.Generic;
using System.Text;

namespace GlitchyEngine.Editor;

/// <summary>
/// Specifies that the OnCreate- and OnUpdate-Methods of this entity are to be be executed in the editor.
/// </summary>
[AttributeUsage(AttributeTargets.Class)]
public sealed class RunInEditModeAttribute : Attribute
{
}
