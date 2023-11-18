namespace GlitchyEngine.Core;

/// <summary>
/// Represents a universally unique identifier (UUID).
/// </summary>
public struct UUID
{
    private ulong _uuid;

    public UUID(ulong uuid)
    {
        _uuid = uuid;
    }

    public static UUID Zero = new UUID(0);

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
