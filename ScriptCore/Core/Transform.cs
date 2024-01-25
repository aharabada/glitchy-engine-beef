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
}
