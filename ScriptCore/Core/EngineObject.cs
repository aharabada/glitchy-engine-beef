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

    /// <summary>Determines whether the specified <see cref="EngineObject"/> is equal to the current <see cref="EngineObject"/>.</summary>
    /// <param name="other">The object to compare with the current object.</param>
    /// <returns>true if the specified object is equal to the current object; otherwise, false.</returns>
    public bool Equals(EngineObject other)
    {
        // TODO: Are we really only interested in what equates to reference equality on the engine side?
        return _uuid == other._uuid;
    }
}
