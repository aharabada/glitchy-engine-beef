using SimpleExec;
using static SimpleExec.Command;

namespace BuildTool.Modules;

class Box2DModule : Module
{
    public static readonly string ModuleName = "Box2D";

    public override string Name => ModuleName;

    public override List<Type> DependencyTypes => [];

    public override async Task<bool> Run(BuildInfo buildInfo)
    {
        // Locate MSBuild.exe before doing any work — fail fast with a clear error.
        string msbuildPath = await LocateMSBuildAsync();

        // Generate Visual Studio 2022 project files. Must be invoked from box2D/scripts so
        // that genie picks up scripts/genie.lua (defines solution "box2d"). The original
        // build_windows_vs2022.cmd runs genie from submodules/bx — that picks up bx's own
        // genie.lua and only generates bx.sln, which is not what we want.
        buildInfo.WorkingDirectory.NavigateFromWorkspaceRoot("GlitchyEngine/vendor/box2D/scripts");

        string geniePath = Path.Combine("..", "submodules", "bx", "tools", "bin", "windows", "genie.exe");
        await RunAsync(geniePath, "--with-windows=10.0 vs2022");

        buildInfo.WorkingDirectory.NavigateFromWorkspaceRoot("GlitchyEngine/vendor/box2D");

        string solutionPath = Path.Combine(".build", "projects", "vs2022", "box2d.sln");
        string target = buildInfo.ForceRebuild ? "-t:Rebuild" : "-t:Build";

        if (buildInfo.BuildDebug)
        {
            await RunAsync(msbuildPath, $"\"{solutionPath}\" {target} -p:Platform=x64 -p:Configuration=Debug -m -verbosity:minimal");
        }

        if (buildInfo.BuildRelease)
        {
            await RunAsync(msbuildPath, $"\"{solutionPath}\" {target} -p:Platform=x64 -p:Configuration=Release -m -verbosity:minimal");
        }

        return true;
    }

    /// <summary>
    /// Locates MSBuild.exe via vswhere (shipped with any Visual Studio 2017+ install).
    /// </summary>
    private static async Task<string> LocateMSBuildAsync()
    {
        string programFilesX86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
        string vswherePath = Path.Combine(programFilesX86, "Microsoft Visual Studio", "Installer", "vswhere.exe");

        if (!File.Exists(vswherePath))
        {
            throw new Exception($"Could not find vswhere.exe at '{vswherePath}'. Is Visual Studio 2017 or newer installed?");
        }

        (string stdout, _) = await ReadAsync(vswherePath,
            "-latest -products * -requires Microsoft.Component.MSBuild -find MSBuild\\**\\Bin\\MSBuild.exe");

        string msbuildPath = stdout.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .FirstOrDefault() ?? "";

        if (string.IsNullOrWhiteSpace(msbuildPath) || !File.Exists(msbuildPath))
        {
            throw new Exception("vswhere could not locate MSBuild.exe. Make sure the 'MSBuild' component is installed with Visual Studio.");
        }

        return msbuildPath;
    }
}
