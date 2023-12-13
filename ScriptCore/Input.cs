using System.Runtime.CompilerServices;

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
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern bool IsKeyPressed(Key key);
    
    /// <summary>
    /// Returns <see langword="true"/> if the specified <see cref="key"/> is in the released state.
    /// </summary>
    /// <param name="key">The key to query.</param>
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern bool IsKeyReleased(Key key);
    
    /// <summary>
    /// Returns <see langword="true"/> if the state of the specified <see cref="key"/> changed this frame (i.e. changed from pressed to released or from released to pressed).
    /// </summary>
    /// <param name="key">The key to query.</param>
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern bool IsKeyToggled(Key key);

    /// <summary>
    /// Returns <see langword="true"/> if <see cref="key"/> is being pressed down this frame
    /// (<see cref="IsKeyPressed"/> was <see langword="false"/> last frame and is <see langword="true"/> this frame).
    /// </summary>
    /// <param name="key">The key to query.</param>
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern bool IsKeyPressing(Key key);
    
    /// <summary>
    /// Returns <see langword="true"/> if <see cref="key"/> is being released this frame
    /// (<see cref="IsKeyPressed"/> was <see langword="true"/> last frame and is <see langword="false"/> this frame).
    /// </summary>
    /// <param name="key">The key to query.</param>
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern bool IsKeyReleasing(Key key);
    
    /// <summary>
    /// Returns <see langword="true"/> if the specified mouse button is in the pressed down state.
    /// </summary>
    /// <param name="mouseButton">The button to query.</param>
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern bool IsMouseButtonPressed(MouseButton mouseButton);

    /// <summary>
    /// Returns <see langword="true"/> if the specified mouse button is in the released state.
    /// </summary>
    /// <param name="mouseButton">The button to query.</param>
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern bool IsMouseButtonReleased(MouseButton mouseButton);
    
    /// <summary>
    /// Returns <see langword="true"/> if the mouse button is being pressed down this frame
    /// (<see cref="IsMouseButtonPressed"/> was <see langword="false"/> last frame and is <see langword="true"/> this frame).
    /// </summary>
    /// <param name="mouseButton">The button to query.</param>
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern bool IsMouseButtonPressing(MouseButton mouseButton);

    /// <summary>
    /// Returns <see langword="true"/> if the mouse button is being released this frame
    /// (<see cref="IsMouseButtonPressed"/> was <see langword="true"/> last frame and is <see langword="false"/> this frame).
    /// </summary>
    /// <param name="mouseButton">The button to query.</param>
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern bool IsMouseButtonReleasing(MouseButton mouseButton);
}
