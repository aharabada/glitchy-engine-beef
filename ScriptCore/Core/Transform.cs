using System.Numerics;
using GlitchyEngine.Math;

namespace GlitchyEngine.Core;

/// <summary>
/// Represents the position, rotation and scale of an entity in the world.
/// <br/><br/>
/// Every entity has a transform component.
/// </summary>
public class Transform : Component
{
    public Entity? Parent
    {
        get
        {
            ScriptGlue.Transform_GetParent(Entity.UUID, out UUID parentId);

            if (parentId == UUID.Zero)
                return null;

            return new Entity(parentId);
        }
        set => ScriptGlue.Transform_SetParent(Entity.UUID, value?._uuid ?? UUID.Zero);
    }

    /// <summary>
    /// Gets or sets the translation (position) of the entity.
    /// </summary>
    public float3 Translation
    {
        get
        {
            ScriptGlue.Transform_GetTranslation(Entity.UUID, out float3 translation);
            return translation;
        }
        set => ScriptGlue.Transform_SetTranslation(Entity.UUID, in value);
    }

    /// <summary>
    /// Gets or sets the rotation of the entity.
    /// </summary>
    public Quaternion Rotation
    {
        get
        {
            ScriptGlue.Transform_GetRotation(Entity.UUID, out Quaternion rotation);
            return rotation;
        }
        set => ScriptGlue.Transform_SetRotation(Entity.UUID, in value);
    }

    /// <summary>
    /// Gets or sets the rotation of the entity in radians around each axis.
    /// </summary>
    public float3 RotationEuler
    {
        get
        {
            ScriptGlue.Transform_GetRotationEuler(Entity.UUID, out float3 rotationEuler);
            return rotationEuler;
        }
        set => ScriptGlue.Transform_SetRotationEuler(Entity.UUID, in value);
    }

    /// <summary>
    /// Gets or sets the rotation of the entity as an axis of rotation and the angle in radians.
    /// </summary>
    public RotationAxisAngle RotationAxisAngle
    {
        get
        {
            ScriptGlue.Transform_GetRotationAxisAngle(Entity.UUID, out RotationAxisAngle rotationEuler);
            return rotationEuler;
        }
        set => ScriptGlue.Transform_SetRotationAxisAngle(Entity.UUID, value);
    }

    /// <summary>
    /// Gets or sets the scale of the entity.
    /// </summary>
    public float3 Scale
    {
        get
        {
            ScriptGlue.Transform_GetScale(Entity.UUID, out float3 scale);
            return scale;
        }
        set => ScriptGlue.Transform_SetScale(Entity.UUID, in value);
    }
}
