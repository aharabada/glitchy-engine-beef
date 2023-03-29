namespace GlitchyEngine.Core;

public class EngineObject
{
    protected internal UUID _uuid;

    /// <summary>
    /// UUID used for identifying the object in the engine.
    /// </summary>
    public UUID UUID => _uuid;

    /// <summary>
    /// Empty constructor not used. Do NOT USE!
    /// </summary>
    protected EngineObject()
    {}

    /// <summary>
    /// Creates a new EngineObject with the given ID.
    /// </summary>
    /// <param name="uuid">UUID of the object.</param>
    internal EngineObject(UUID uuid)
    {
        _uuid = uuid;
    }
}
