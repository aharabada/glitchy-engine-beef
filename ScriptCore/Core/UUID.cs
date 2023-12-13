namespace GlitchyEngine.Core;

/// <summary>
/// Represents a universally unique identifier (UUID).
/// </summary>
public struct UUID
{
    private ulong _uuid;

    /// <summary>
    /// Create a new instance of a <see cref="UUID"/> with the given value as ID.
    /// </summary>
    /// <param name="uuid">The id.</param>
    public UUID(ulong uuid)
    {
        _uuid = uuid;
    }

    /// <summary>
    /// A <see cref="UUID"/> with the ID 0.
    /// </summary>
    public static readonly UUID Zero = new UUID(0);

    /// <summary>
    /// Creates a new random <see cref="UUID"/>.
    /// </summary>
    /// <returns>The newly created <see cref="UUID"/></returns>
    public static UUID CreateNew()
    {
        ScriptGlue.UUID_CreateNew(out UUID id);
        return id;
    }

    public static bool operator ==(UUID left, UUID right) => left._uuid == right._uuid;

    public static bool operator !=(UUID left, UUID right) => left._uuid != right._uuid;

    public override bool Equals(object obj)
    {
        if (obj is UUID other)
        {
            return this == other;
        }

        return false;
    }

    public override int GetHashCode()
    {
        return _uuid.GetHashCode();
    }

    public override string ToString()
    {
        return _uuid.ToString();
    }
}
