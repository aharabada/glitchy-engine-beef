using GlitchyEngine.Math;

namespace GlitchyEngine;

public class RigidBody2D : Component
{
    /// <summary>
    /// Apply a force at a world point.
    /// If the force is not applied at the center of mass, it will generate a torque and affect the angular velocity.
    /// This wakes up the body.
    /// </summary>
    /// <param name="force">The world force vector, usually in Newtons (N).</param>
    /// <param name="point">The world position of the point of application.</param>
    /// <param name="wakeUp">Wake up the body</param>
    public void ApplyForce(Vector2 force, Vector2 point, bool wakeUp = true)
    {
        ScriptGlue.RigidBody2D_ApplyForce(Entity._uuid, force, point, wakeUp);
    }

    /// <summary>
    /// Apply a force to the center of mass.
    /// This wakes up the body.
    /// </summary>
    /// <param name="force">The world force vector, usually in Newtons (N).</param>
    /// <param name="wakeUp">Wake up the body</param>
    public void ApplyForceToCenter(Vector2 force, bool wakeUp = true)
    {
        ScriptGlue.RigidBody2D_ApplyForceToCenter(Entity._uuid, force, wakeUp);
    }
}