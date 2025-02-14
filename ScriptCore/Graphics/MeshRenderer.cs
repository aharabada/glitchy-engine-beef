using GlitchyEngine.Core;

namespace GlitchyEngine.Graphics;

/// <summary>
/// Renders a Mesh. The Mesh can be specified by adding a <see cref="Mesh"/> component to the same <see cref="Entity"/>.
/// </summary>
public class MeshRenderer : Component
{
    /// <summary>
    /// Gets or sets the Material of this <see cref="MeshRenderer"/>.
    /// </summary>
    /// <remarks>
    /// If you get the <see cref="Material"/> and it is not yet a runtime-instance,
    /// a new runtime-instance will be created and returned in its place.
    /// </remarks>
    public Material Material
    {
        get
        {
            ScriptGlue.MeshRenderer_GetMaterial(_uuid, out UUID materialHandle);

            return new Material { _uuid = materialHandle };
        }
        set => ScriptGlue.MeshRenderer_SetMaterial(_uuid, value._uuid);
    }
}
