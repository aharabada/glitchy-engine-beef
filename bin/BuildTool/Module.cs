namespace BuildTool;

abstract class Module
{
    public abstract string Name { get; }

    public List<Module> Dependencies { get; } = new();
    public abstract List<Type> DependencyTypes { get; }

    public abstract Task<bool> Run(BuildInfo buildInfo);
}
