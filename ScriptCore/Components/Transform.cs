using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine;

public class Transform : Component
{
    public float3 Translation
    {
        get
        {
            ScriptGlue.Transform_GetTranslation(Entity.UUID, out float3 translation);
            return translation;
        }
        set
        {
            ScriptGlue.Transform_SetTranslation(Entity.UUID, in value);
        }
    }
}
