namespace GlitchyEngine.Core;

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

    public override string ToString()
    {
        return _uuid.ToString();
    }
}
