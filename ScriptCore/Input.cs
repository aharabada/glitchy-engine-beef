using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace GlitchyEngine;

/// <summary>
/// Provides methods to query the state of the input devices.
/// </summary>
public static class Input
{
    /// <summary>
    /// Returns <see langword="true"/> if the specified key is in the pressed down state.
    /// </summary>
    /// <param name="key">The key to query.</param>
    public static bool IsKeyPressed(Key key) => ScriptGlue.Input_IsKeyPressed(key);

    /// <summary>
    /// Returns <see langword="true"/> if the specified <see cref="key"/> is in the released state.
    /// </summary>
    /// <param name="key">The key to query.</param>
    public static bool IsKeyReleased(Key key) => ScriptGlue.Input_IsKeyReleased(key);

    /// <summary>
    /// Returns <see langword="true"/> if the state of the specified <see cref="key"/> changed this frame (i.e. changed from pressed to released or from released to pressed).
    /// </summary>
    /// <param name="key">The key to query.</param>
    public static bool IsKeyToggled(Key key) => ScriptGlue.Input_IsKeyToggled(key);

    /// <summary>
    /// Returns <see langword="true"/> if <see cref="key"/> is being pressed down this frame
    /// (<see cref="IsKeyPressed"/> was <see langword="false"/> last frame and is <see langword="true"/> this frame).
    /// </summary>
    /// <param name="key">The key to query.</param>
    public static bool IsKeyPressing(Key key) => ScriptGlue.Input_IsKeyPressing(key);

    /// <summary>
    /// Returns <see langword="true"/> if <see cref="key"/> is being released this frame
    /// (<see cref="IsKeyPressed"/> was <see langword="true"/> last frame and is <see langword="false"/> this frame).
    /// </summary>
    /// <param name="key">The key to query.</param>
    public static bool IsKeyReleasing(Key key) => ScriptGlue.Input_IsKeyReleasing(key);

    /// <summary>
    /// Returns <see langword="true"/> if the specified mouse button is in the pressed down state.
    /// </summary>
    /// <param name="mouseButton">The button to query.</param>
    public static bool IsMouseButtonPressed(MouseButton mouseButton) => ScriptGlue.Input_IsMouseButtonPressed(mouseButton);

    /// <summary>
    /// Returns <see langword="true"/> if the specified mouse button is in the released state.
    /// </summary>
    /// <param name="mouseButton">The button to query.</param>
    public static bool IsMouseButtonReleased(MouseButton mouseButton) => ScriptGlue.Input_IsMouseButtonReleased(mouseButton);

    /// <summary>
    /// Returns <see langword="true"/> if the mouse button is being pressed down this frame
    /// (<see cref="IsMouseButtonPressed"/> was <see langword="false"/> last frame and is <see langword="true"/> this frame).
    /// </summary>
    /// <param name="mouseButton">The button to query.</param>
    public static bool IsMouseButtonPressing(MouseButton mouseButton) => ScriptGlue.Input_IsMouseButtonPressing(mouseButton);

    /// <summary>
    /// Returns <see langword="true"/> if the mouse button is being released this frame
    /// (<see cref="IsMouseButtonPressed"/> was <see langword="true"/> last frame and is <see langword="false"/> this frame).
    /// </summary>
    /// <param name="mouseButton">The button to query.</param>
    public static bool IsMouseButtonReleasing(MouseButton mouseButton) => ScriptGlue.Input_IsMouseButtonReleasing(mouseButton);
}
