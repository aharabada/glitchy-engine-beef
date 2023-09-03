using GlitchyEngine.Math;

namespace GlitchyEngine;

public class Rigidbody2D : Component
{
    /// <summary>
    /// Apply a force at a world point.
    /// If the force is not applied at the center of mass, it will generate a torque and affect the angular velocity.
    /// This wakes up the body.
    /// </summary>
    /// <param name="force">The world force vector, usually in Newtons (N).</param>
    /// <param name="point">The world position of the point of application.</param>
    /// <param name="wakeUp">Wake up the body</param>
    public void ApplyForce(float2 force, float2 point, bool wakeUp = true)
    {
        ScriptGlue.Rigidbody2D_ApplyForce(Entity._uuid, force, point, wakeUp);
    }

    /// <summary>
    /// Apply a force to the center of mass.
    /// This wakes up the body.
    /// </summary>
    /// <param name="force">The world force vector, usually in Newtons (N).</param>
    /// <param name="wakeUp">Wake up the body</param>
    public void ApplyForceToCenter(float2 force, bool wakeUp = true)
    {
        ScriptGlue.Rigidbody2D_ApplyForceToCenter(Entity._uuid, force, wakeUp);
    }
    
    /// <summary>
    /// Gets or sets the global position of the rigidbody.
    /// </summary>
    public float2 Position
    {
        get
        {
            ScriptGlue.Rigidbody2D_GetPosition(Entity._uuid, out float2 position);

            return position;
        }
        set => ScriptGlue.Rigidbody2D_SetPosition(Entity._uuid, value);
    }
    
    /// <summary>
    /// Gets or sets the global rotation of the rigidbody.
    /// </summary>
    public float Rotation
    {
        get
        {
            ScriptGlue.Rigidbody2D_GetRotation(Entity._uuid, out float rotation);

            return rotation;
        }
        set => ScriptGlue.Rigidbody2D_SetRotation(Entity._uuid, value);
    }
}
