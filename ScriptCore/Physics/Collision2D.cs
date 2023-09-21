using System.Runtime.InteropServices;
using GlitchyEngine.Core;

namespace GlitchyEngine.Physics;

[StructLayout(LayoutKind.Sequential, Pack=1)]
public struct Collision2D
{
    private UUID _entity;
    private UUID _otherEntity;

    private UUID _rigidbody;
    private UUID _otherRigidbody;

    /// <summary>
    /// Gets the Entity whose Collider takes part in the collision.
    /// This entity is either the entity of the script instance receiving the event or a child of it.
    /// </summary>
    public Entity Entity => new(_entity);
    /// <summary>
    /// Gets the other Entity whose collider takes part in the collision.
    /// </summary>
    public Entity OtherEntity => new(_otherEntity);

    /// <summary>
    /// Gets the rigidbody whose Collider takes part in the collision.
    /// This Rigidbody is either a component of the entity whose script instance received the event or a parent of it.
    /// </summary>
    public Rigidbody2D Rigidbody => new() { _uuid = _entity };

    /// <summary>
    /// Gets the other rigidbody whose Collider takes part in the collision.
    /// </summary>
    public Rigidbody2D OtherRigidbody => new() { _uuid = _otherEntity };
}
