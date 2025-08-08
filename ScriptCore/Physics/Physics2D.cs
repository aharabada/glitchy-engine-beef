using GlitchyEngine.Math;

namespace GlitchyEngine.Physics;

/// <summary>
/// Allows changing the properties of the 2D physics simulation in the current scene.
/// </summary>
public static class Physics2D
{
    /// <summary>
    /// Gets or sets the gravity of the current scene.
    /// </summary>
    public static float2 Gravity
    {
        get
        {
            ScriptGlue.Physics2D_GetGravity(out float2 gravity);
            return gravity;
        }
        set => ScriptGlue.Physics2D_SetGravity(value);
    }
}