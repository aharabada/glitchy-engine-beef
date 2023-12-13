namespace GlitchyEngine.Core;

/// <summary>
/// The base class for all classes that represent something that belongs to the engine (Entities, Components and Assets).
/// </summary>
public abstract class EngineObject
{
    protected internal UUID _uuid;

    /// <summary>
    /// UUID (Universally Unique Identifier) used for identifying the object in the engine.
    /// </summary>
    public UUID UUID => _uuid;

    /// <summary>
    /// Empty constructor not used. Do NOT USE!
    /// </summary>
    protected EngineObject() { }

    /// <summary>
    /// Creates a new EngineObject with the given ID.
    /// </summary>
    /// <param name="uuid">UUID of the object.</param>
    internal EngineObject(UUID uuid)
    {
        _uuid = uuid;
    }
}
