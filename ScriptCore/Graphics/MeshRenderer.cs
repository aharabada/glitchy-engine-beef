using GlitchyEngine.Core;

namespace GlitchyEngine.Graphics;

/// <summary>
/// Renders a Mesh. The Mesh can be specified by adding a <see cref="Mesh"/> component to the same <see cref="Entity"/>.
/// </summary>
public class MeshRenderer : Component
{
    /// <summary>
    /// Gets or sets the instance Material of this <see cref="MeshRenderer"/>.
    /// </summary>
    /// <remarks>
    /// If you get the <see cref="GlitchyEngine.Graphics.Material"/> and it is not yet a runtime-instance,
    /// a new runtime-instance will be created and returned in its place. If you want to get the actual material instance,
    /// use <see cref="SharedMaterial"/> instead.
    /// <para>
    /// <b>Note:</b> While the behaviour differs for getting <see cref="SharedMaterial"/> and <see cref="Material"/>,
    /// the setter behaves identical for both properties.
    /// </para>
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

    /// <summary>
    /// Gets or sets the shared Material of this <see cref="MeshRenderer"/>.
    /// </summary>
    /// <remarks>
    /// <para>
    /// In contrast to the <see cref="Material"/>-property this will not create a new runtime-instance and instead
    /// always return the actual Material-Asset.
    /// Making changes to the instance returned by this property will have global effect.
    /// <see cref="GlitchyEngine.Graphics.Material"/> is used (and obviously instances/children of it).
    /// </para>
    /// <para>
    /// <b>Note:</b> While the behaviour differs for getting <see cref="SharedMaterial"/> and <see cref="Material"/>,
    /// the setter behaves identical for both properties.
    /// </para>
    /// </remarks>
    public Material SharedMaterial
    {
        get
        {
            ScriptGlue.MeshRenderer_GetSharedMaterial(_uuid, out UUID materialHandle);

            return new Material { _uuid = materialHandle };
        }
        set => ScriptGlue.MeshRenderer_SetMaterial(_uuid, value._uuid);
    }
}
