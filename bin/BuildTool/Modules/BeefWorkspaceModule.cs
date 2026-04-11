using static SimpleExec.Command;

namespace BuildTool.Modules;

class BeefWorkspaceModule : Module
{
    public static readonly string ModuleName = "BeefWorkspace";

    public override string Name => ModuleName;

    public override List<Type> DependencyTypes => [typeof(GlitchyEngineHelperModule), typeof(Box2DModule)];

    public override async Task<bool> Run(BuildInfo buildInfo)
    {
        if (buildInfo.BuildDebug)
        {
            await RunAsync("beefbuild", $"-workspace={buildInfo.WorkingDirectory.WorkspaceRoot} -config=debug");
        }

        if (buildInfo.BuildRelease)
        {
            await RunAsync("beefbuild", $"-workspace={buildInfo.WorkingDirectory.WorkspaceRoot} -config=release");
        }

        return true;
    }
}
