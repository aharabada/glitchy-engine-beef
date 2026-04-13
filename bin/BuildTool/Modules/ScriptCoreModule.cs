using SimpleExec;

namespace BuildTool.Modules;

class ScriptCoreModule : Module
{
    public static readonly string ModuleName = "ScriptCore";

    public override string Name => ModuleName;

    public override List<Type> DependencyTypes => [typeof(SetupNethostModule), typeof(BeefWorkspaceModule)];

    public override async Task<bool> Run(BuildInfo buildInfo)
    {
        string projectFile = Path.Join(buildInfo.WorkingDirectory.WorkspaceRoot, "ScriptCore", "ScriptCore.csproj");

        if (buildInfo.BuildDebug)
        {
            await Command.RunAsync("dotnet", $"build \"{projectFile}\" -c Debug");
        }

        if (buildInfo.BuildRelease)
        {
            await Command.RunAsync("dotnet", $"build \"{projectFile}\" -c Release");
        }

        return true;
    }

    protected override List<WatchedSource> GetWatchedSources(BuildInfo buildInfo)
    {
        List<WatchedSource> sources = new();

        // Watch ScriptGlue-Definitions file by content
        sources.Add(new WatchedSource("generated/ScriptGlue.json", WatchMode.Content));

        // Watch source files by metadata
        sources.Add(new WatchedSource("ScriptCore/", WatchMode.Metadata)
        {
            Recursive = true,
            ExcludedDirectories =
            [
                "bin",
                "obj"
            ]
        });

        return sources;
    }
}