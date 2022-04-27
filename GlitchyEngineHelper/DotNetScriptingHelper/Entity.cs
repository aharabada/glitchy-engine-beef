namespace DotNetScriptingHelper;

public struct Entity
{
    public EcsEntity Handle { get; }
    public IntPtr Scene { get; }

    public bool IsValid => Handle.IsValid;

    public Entity(EcsEntity handle, IntPtr scene)
    {
        Handle = handle;
        Scene = scene;
    }

    // TODO: Get Parent, Children
}
