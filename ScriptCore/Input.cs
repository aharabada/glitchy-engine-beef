using System.Runtime.CompilerServices;

namespace GlitchyEngine;

public static class Input
{
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern bool IsKeyPressed(Key key);
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern bool IsKeyReleased(Key key);
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern bool IsKeyToggled(Key key);

    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern bool IsKeyPressing(Key key);
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern bool IsKeyReleasing(Key key);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern bool IsMouseButtonPressed(MouseButton mouseButton);
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern bool IsMouseButtonReleased(MouseButton mouseButton);
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern bool IsMouseButtonPressing(MouseButton mouseButton);
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern bool IsMouseButtonReleasing(MouseButton mouseButton);
}
