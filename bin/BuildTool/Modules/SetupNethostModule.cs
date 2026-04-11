using static SimpleExec.Command;

namespace BuildTool.Modules;

class SetupNethostModule : Module
{
    public static readonly string ModuleName = "SetupNethost";

    public override string Name => ModuleName;

    public override List<Type> DependencyTypes => [];

    public override async Task<bool> Run(BuildInfo buildInfo)
    {
        buildInfo.WorkingDirectory.NavigateFromWorkspaceRoot("GlitchyEngine/vendor/NetHostBeef");

        string targetPath = buildInfo.WorkingDirectory.GetRelativePath("./NetHostBeef/nethost/");

        if (buildInfo.ForceRebuild || !Directory.Exists(targetPath))
        {
            if (Directory.Exists(targetPath))
            {
                Console.WriteLine("Removing existing nethost directory...");
                Directory.Delete(targetPath, true);
                Console.WriteLine("Done.");
            }

            Console.WriteLine("Donwloading nethost...");
            await RunAsync("powershell", "./downloadNethost.ps1");
            Console.WriteLine("Done.");
        }
        else
        {
            Console.WriteLine("Nethost already exists. Use --force-rebuild to force download.");
        }

        return true;
    }
}
