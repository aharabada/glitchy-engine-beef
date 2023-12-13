using GlitchyEngine.Components;
using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine;

/// <summary>
/// Represents the position, rotation and scale of an entity in the world.
/// <br/><br/>
/// Every entity has a transform component.
/// </summary>
public class Transform : Component
{
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
