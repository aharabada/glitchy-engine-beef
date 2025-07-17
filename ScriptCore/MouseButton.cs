using GlitchyEngine.Core;

namespace GlitchyEngine;

/// <summary>
/// An enum of all mouse buttons that can be queried using methods in <see cref="Input"/>.
/// </summary>
[EngineClass("GlitchyEngine.Events.MouseButton")]
public enum MouseButton : byte
{
    None = 0,
    LeftButton,
    RightButton,
    MiddleButton,
    XButton1,
    XButton2,
}
