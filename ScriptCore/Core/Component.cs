namespace GlitchyEngine.Core;

/// <summary>
/// The base class for all Components.
/// </summary>
public abstract class Component : EngineObject
{
    /// <summary>
    /// Gets the entity that this component is attached to.
    /// </summary>
    public Entity Entity => new(_uuid);
}