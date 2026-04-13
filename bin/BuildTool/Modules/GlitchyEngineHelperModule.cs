using static SimpleExec.Command;

namespace BuildTool.Modules;

class GlitchyEngineHelperModule : Module
{
    public static readonly string ModuleName = "GlitchyEngineHelper";

    public override string Name => ModuleName;

    public override List<Type> DependencyTypes => [];

    public override async Task<bool> Run(BuildInfo buildInfo)
    {
        buildInfo.WorkingDirectory.NavigateFromWorkspaceRoot("GlitchyEngineHelper");

        if (buildInfo.BuildDebug)
        {
            await RunAsync("cmake", "--preset x64-debug");
            await RunAsync("cmake", "--build --preset x64-debug");
        }

        if (buildInfo.BuildRelease)
        {
            await RunAsync("cmake", "--preset x64-release");
            await RunAsync("cmake", "--build --preset x64-release");
        }

        return true;
    }

    protected override List<WatchedSource> GetWatchedSources(BuildInfo buildInfo)
    {
        List<WatchedSource> sources = new();

        // Watch ScriptGlue-Definitions file by content
        sources.Add(new WatchedSource("GlitchyEngineHelper", WatchMode.Metadata)
        {
            Recursive = true,
            ExcludedSubpaths =
            [
                ".vs",
                "out",
                "src",
                "BeefProj.toml"
            ]
        });

        return sources;
    }
}
