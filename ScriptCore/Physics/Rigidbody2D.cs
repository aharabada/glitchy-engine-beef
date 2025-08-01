using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine.Physics;

/// <summary>
/// Rigid body component for 2D physics.
/// </summary>
[EngineClass("GlitchyEngine.World.Rigidbody2DComponent")]
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
        ScriptGlue.Rigidbody2D_ApplyForce(_uuid, force, point, wakeUp);
    }

    /// <summary>
    /// Apply a force to the center of mass.
    /// This wakes up the body.
    /// </summary>
    /// <param name="force">The world force vector, usually in Newtons (N).</param>
    /// <param name="wakeUp">Wake up the body</param>
    public void ApplyForceToCenter(float2 force, bool wakeUp = true)
    {
        ScriptGlue.Rigidbody2D_ApplyForceToCenter(_uuid, force, wakeUp);
    }
    
    /// <summary>
    /// Gets or sets the global position of the rigidbody.
    /// </summary>
    public float2 Position
    {
        get
        {
            ScriptGlue.Rigidbody2D_GetPosition(_uuid, out float2 position);

            return position;
        }
        set => ScriptGlue.Rigidbody2D_SetPosition(_uuid, value);
    }
    
    /// <summary>
    /// Gets or sets the global rotation of the rigidbody.
    /// </summary>
    public float Rotation
    {
        get
        {
            ScriptGlue.Rigidbody2D_GetRotation(_uuid, out float rotation);

            return rotation;
        }
        set => ScriptGlue.Rigidbody2D_SetRotation(_uuid, value);
    }
    
    /// <summary>
    /// Gets or sets the linear velocity of the rigidbody.
    /// </summary>
    public float2 LinearVelocity
    {
        get
        {
            ScriptGlue.Rigidbody2D_GetLinearVelocity(_uuid, out float2 velocity);

            return velocity;
        }
        set => ScriptGlue.Rigidbody2D_SetLinearVelocity(_uuid, value);
    }
    
    /// <summary>
    /// Gets or sets the angular velocity of the rigidbody.
    /// </summary>
    public float AngularVelocity
    {
        get
        {
            ScriptGlue.Rigidbody2D_GetAngularVelocity(_uuid, out float velocity);

            return velocity;
        }
        set => ScriptGlue.Rigidbody2D_SetAngularVelocity(_uuid, value);
    }
    
    /// <summary>
    /// Gets or sets whether the rigidbody can rotate or not.
    /// </summary>
    public bool FixedRotation
    {
        get
        {
            ScriptGlue.Rigidbody2D_IsFixedRotation(_uuid, out bool isFixedRotation);

            return isFixedRotation;
        }
        set => ScriptGlue.Rigidbody2D_SetFixedRotation(_uuid, value);
    }

    /// <summary>
    /// Gets or sets the body type of the rigidbody.
    /// </summary>
    public BodyType BodyType
    {
        get
        {
            ScriptGlue.Rigidbody2D_GetBodyType(_uuid, out BodyType bodyType);

            return bodyType;
        }
        set => ScriptGlue.Rigidbody2D_SetBodyType(_uuid, value);
    }
    

    /// <summary>
    /// Gets or sets the gravity scale of this rigidbody.
    /// E.g. a value of 0.0 means, that the rigidbody is not affected by gravity and a value of -1.0 means, that it gravity is inverted.
    /// </summary>
    public float GravityScale
    {
        get
        {
            ScriptGlue.Rigidbody2D_GetGravityScale(_uuid, out float gravityScale);

            return gravityScale;
        }
        set => ScriptGlue.Rigidbody2D_SetGravityScale(_uuid, value);
    }
}
