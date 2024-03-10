namespace GlitchyEngine.Editor;

/// <summary>
/// Flags to controls the visibility of the entity in the editor and how it can be interacted with for editing.
/// </summary>
public enum EditorFlags : byte
{
    /// <summary>
    /// The default behaviour: The entity is visible in the hierarchy and in the scene, and can be interacted with. 
    /// </summary>
    Default = 0,
    /// <summary>
    /// The entity is hidden in the hierarchy.
    /// </summary>
    HideInHierarchy = 1,
    /// <summary>
    /// The entity is hidden in the scene.
    /// </summary>
    HideInScene = 2,
    /// <summary>
    /// The entity will not be saved.
    /// </summary>
    DontSave = 4
}
