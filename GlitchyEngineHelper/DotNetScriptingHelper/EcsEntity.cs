namespace DotNetScriptingHelper;

public readonly struct EcsEntity
{
    // Binary Format:
    // Bits: [0 - 31] [32 - 64]
    // Data: Version    Index

    private readonly ulong _id;
    
    internal uint Version => (uint)_id;
    
    internal uint Index => (uint)(_id >> 32);
    
    public EcsEntity(uint index, uint version)
    {
        _id = ((ulong)index << 32) | version;
    }

    public bool IsValid => Index != InvalidEntity.Index;

    public static readonly EcsEntity InvalidEntity = new(uint.MaxValue, 0);
}
