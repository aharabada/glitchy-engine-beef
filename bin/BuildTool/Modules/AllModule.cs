namespace BuildTool.Modules;

class AllModule : Module
{
    public static readonly string ModuleName = "All";
    public override string Name => ModuleName;
    public override List<Type> DependencyTypes => [typeof(BeefWorkspaceModule), typeof(ScriptCoreModule)];

    public override Task<bool> Run(BuildInfo buildInfo)
    {
        return Task.FromResult(true);
    }
}
