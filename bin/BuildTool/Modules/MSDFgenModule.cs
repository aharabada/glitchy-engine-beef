using static SimpleExec.Command;

namespace BuildTool.Modules;

class MSDFgenModule : Module
{
    public static readonly string ModuleName = "MSDFgen";

    public override string Name => ModuleName;

    public override List<Type> DependencyTypes => [typeof(FreetypeStackModule)];

    public override async Task<bool> Run(BuildInfo buildInfo)
    {
        string workspaceRoot = buildInfo.WorkingDirectory.WorkspaceRoot;
        string msdfgenSrcDir = Path.Combine(workspaceRoot, "GlitchyEngine", "vendor", "msdfgen");
        string buildDir = Path.Combine(workspaceRoot, "build", "msdfgen");
        string distRoot = Path.Combine(msdfgenSrcDir, "msdfgen-beef", "dist");

        // Freetype headers + libs come from the FreetypeStack module output.
        string ftIncludeDir = Path.Combine(workspaceRoot,
            "GlitchyEngine", "vendor", "freetype", "harfbuzz", "subprojects", "freetype", "include");
        string ftLibRelease = Path.Combine(workspaceRoot,
            "GlitchyEngine", "vendor", "freetype", "dist", "win64", "release", "freetype.lib");
        string ftLibDebug = Path.Combine(workspaceRoot,
            "GlitchyEngine", "vendor", "freetype", "dist", "win64", "debug", "freetype.lib");

        if (buildInfo.ForceRebuild && Directory.Exists(buildDir))
            Directory.Delete(buildDir, recursive: true);

        // Configure once (multi-config VS generator handles both Debug and Release).
        if (!Directory.Exists(buildDir))
        {
            Console.WriteLine($"[MSDFgen] Configuring CMake -> {buildDir}");
            await RunAsync("cmake",
                $"-S \"{msdfgenSrcDir}\" -B \"{buildDir}\" -A x64 " +
                $"-DFREETYPE_INCLUDE_DIR=\"{ftIncludeDir}\" " +
                $"-DFREETYPE_LIBRARY=\"{ftLibRelease}\" " +
                $"-DFREETYPE_LIBRARY_DEBUG=\"{ftLibDebug}\"");
        }

        if (buildInfo.BuildDebug)
        {
            Console.WriteLine("[MSDFgen] Building Debug");
            await RunAsync("cmake", $"--build \"{buildDir}\" --config Debug");

            string debugDist = Path.Combine(distRoot, "Debug-Win64");
            Directory.CreateDirectory(debugDist);
            CopyLibs(buildDir, "Debug", debugDist);
        }

        if (buildInfo.BuildRelease)
        {
            Console.WriteLine("[MSDFgen] Building Release");
            await RunAsync("cmake", $"--build \"{buildDir}\" --config Release");

            string releaseDist = Path.Combine(distRoot, "Release-Win64");
            Directory.CreateDirectory(releaseDist);
            CopyLibs(buildDir, "Release", releaseDist);
        }

        return true;
    }

    private static void CopyLibs(string buildDir, string config, string distDir)
    {
        Console.WriteLine($"[MSDFgen] Copying {config} artefacts to {distDir}");

        // msdfgen-core and msdfgen-ext are built inside the msdfgen/ subdirectory
        Copy(Path.Combine(buildDir, "msdfgen", config, "msdfgen-core.lib"), distDir);
        Copy(Path.Combine(buildDir, "msdfgen", config, "msdfgen-ext.lib"), distDir);
        // msdfgen_c (our C wrapper stub) is at the top-level build dir
        Copy(Path.Combine(buildDir, config, "msdfgen_c.lib"), distDir);
    }

    private static void Copy(string src, string distDir)
    {
        if (!File.Exists(src))
            throw new FileNotFoundException($"Expected build artefact not found: {src}");

        string dst = Path.Combine(distDir, Path.GetFileName(src));
        File.Copy(src, dst, overwrite: true);
    }
}
