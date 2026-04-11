using SimpleExec;

namespace BuildTool.Modules;

class ScriptCoreModule : Module
{
    public static readonly string ModuleName = "ScriptCore";

    public override string Name => ModuleName;

    public override List<Type> DependencyTypes => [typeof(SetupNethostModule), typeof(BeefWorkspaceModule)];

    public override async Task<bool> Run(BuildInfo buildInfo)
    {
        string projectFile = Path.Join(buildInfo.WorkingDirectory.WorkspaceRoot, "ScriptCore/ScriptCore.csproj");

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
}