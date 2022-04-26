namespace DotNetScriptingHelper;

public struct Entity
{
    public EcsEntity Handle { get; private set; }
    // TODO: Scene

    public bool IsValid => Handle.IsValid;

    public Entity(EcsEntity handle)
    {
        Handle = handle;
    }

    // TODO: Get Parent, Children
}
