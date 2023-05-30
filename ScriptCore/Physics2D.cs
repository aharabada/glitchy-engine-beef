using GlitchyEngine.Math;

namespace GlitchyEngine;

/// <summary>
/// Allows changing the properties of the 2D physics simulation in the current scene.
/// </summary>
public static class Physics2D
{
    /// <summary>
    /// Gets or sets the gravity of the current scene.
    /// </summary>
    public static Vector2 Gravity
    {
        get
        {
            ScriptGlue.Physics2D_GetGravity(out Vector2 gravity);
            return gravity;
        }
        set => ScriptGlue.Physics2D_SetGravity(in value);
    }
}