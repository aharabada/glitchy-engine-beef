using SimpleExec;
using static SimpleExec.Command;

namespace BuildTool.Modules;

class FreetypeStackModule : Module
{
    public static readonly string ModuleName = "FreetypeStack";

    public override string Name => ModuleName;

    public override List<Type> DependencyTypes => [];

    /// <summary>
    /// Per-flavor build configuration. Each active flavor produces its own set of static
    /// libs under <c>dist/win64/{DistSubdir}</c>, so a Beef Debug engine links against the
    /// /MTd set and a Beef Release engine against the /MT set — matching Box2D's convention
    /// and avoiding the <c>_ITERATOR_DEBUG_LEVEL</c> / <c>RuntimeLibrary</c> link errors that
    /// a shared output directory would cause.
    /// </summary>
    private record Flavor(string Name, string Buildtype, string Vscrt, string DistSubdir);

    private static readonly Flavor DebugFlavor   = new("debug",   "debug",   "mtd", "debug");
    private static readonly Flavor ReleaseFlavor = new("release", "release", "mt",  "release");

    public override async Task<bool> Run(BuildInfo buildInfo)
    {
        if (!buildInfo.BuildDebug && !buildInfo.BuildRelease)
            return true;

        await EnsureToolsAvailableAsync();

        Dictionary<string, string> vsEnv = await CaptureVsDevEnvAsync();

        string workspaceRoot = buildInfo.WorkingDirectory.WorkspaceRoot;
        string vendorRoot = Path.Combine(workspaceRoot, "GlitchyEngine", "vendor", "freetype");
        string distRoot = Path.Combine(vendorRoot, "dist", "win64");
        string hbSrcDir = Path.Combine(vendorRoot, "harfbuzz");
        string fribidiSrcDir = Path.Combine(vendorRoot, "fribidi");

        // Build directories live outside the submodules so Meson output never dirties them.
        string buildRoot = Path.Combine(workspaceRoot, "build", "freetype-stack");
        Directory.CreateDirectory(buildRoot);

        if (buildInfo.BuildDebug)
            await BuildFlavorAsync(DebugFlavor, hbSrcDir, fribidiSrcDir, buildRoot, distRoot, vsEnv, buildInfo.ForceRebuild);

        if (buildInfo.BuildRelease)
            await BuildFlavorAsync(ReleaseFlavor, hbSrcDir, fribidiSrcDir, buildRoot, distRoot, vsEnv, buildInfo.ForceRebuild);

        return true;
    }

    private static async Task BuildFlavorAsync(
        Flavor flavor,
        string hbSrcDir, string fribidiSrcDir,
        string buildRoot, string distRoot,
        Dictionary<string, string> vsEnv,
        bool forceRebuild)
    {
        string hbBuildDir = Path.Combine(buildRoot, $"harfbuzz-{flavor.Name}");
        string fribidiBuildDir = Path.Combine(buildRoot, $"fribidi-{flavor.Name}");
        string distDir = Path.Combine(distRoot, flavor.DistSubdir);

        if (forceRebuild)
        {
            if (Directory.Exists(hbBuildDir)) Directory.Delete(hbBuildDir, recursive: true);
            if (Directory.Exists(fribidiBuildDir)) Directory.Delete(fribidiBuildDir, recursive: true);
        }

        await BuildHarfbuzzAsync(flavor, hbSrcDir, hbBuildDir, vsEnv);
        await BuildFribidiAsync(flavor, fribidiSrcDir, fribidiBuildDir, vsEnv);

        Directory.CreateDirectory(distDir);
        CopyArtefacts(hbBuildDir, fribidiBuildDir, distDir);
    }

    /// <summary>
    /// Verifies that meson, ninja and pkg-config are available. These are external
    /// prerequisites that the user must install once — we don't try to auto-install them
    /// because each has a different canonical install path and package manager on Windows.
    /// </summary>
    private static async Task EnsureToolsAvailableAsync()
    {
        async Task Check(string tool, string args, string hint)
        {
            try
            {
                await ReadAsync(tool, args);
            }
            catch (Exception ex)
            {
                throw new Exception(
                    $"Required tool '{tool}' not found on PATH. {hint}", ex);
            }
        }

        await Check("meson", "--version",
            "Install with 'uv tool install meson' (if you use uv) or 'pip install --user meson'.");
        await Check("ninja", "--version",
            "Install with 'scoop install ninja' or 'winget install Ninja-build.Ninja'.");
        await Check("pkg-config", "--version",
            "Install with 'scoop install pkg-config' or 'choco install pkgconfiglite'.");
    }

    /// <summary>
    /// Runs vcvarsall.bat x64 and captures the resulting environment block so that Meson's
    /// subprocesses find cl.exe, link.exe and the MSVC headers/libs without needing the
    /// developer to open a Developer Command Prompt manually.
    /// </summary>
    private static async Task<Dictionary<string, string>> CaptureVsDevEnvAsync()
    {
        string programFilesX86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
        string vswherePath = Path.Combine(programFilesX86, "Microsoft Visual Studio", "Installer", "vswhere.exe");

        if (!File.Exists(vswherePath))
        {
            throw new Exception(
                $"Could not find vswhere.exe at '{vswherePath}'. Is Visual Studio 2017 or newer installed?");
        }

        (string stdout, _) = await ReadAsync(vswherePath,
            "-latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 " +
            "-find VC/Auxiliary/Build/vcvarsall.bat");

        string vcvarsallPath = stdout
            .Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .FirstOrDefault() ?? "";

        if (string.IsNullOrWhiteSpace(vcvarsallPath) || !File.Exists(vcvarsallPath))
        {
            throw new Exception(
                "vswhere could not locate vcvarsall.bat. Make sure the 'Desktop development with C++' workload " +
                "(component 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64') is installed.");
        }

        // Quadruple-quoted cmd /c trick: outer quotes wrap the whole payload, inner quotes
        // protect the vcvarsall path because it typically contains a space.
        (string envDump, _) = await ReadAsync("cmd",
            $"/d /c \"\"{vcvarsallPath}\" x64 >nul && set\"");

        var env = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (string line in envDump.Split('\n', StringSplitOptions.RemoveEmptyEntries))
        {
            int idx = line.IndexOf('=');
            if (idx <= 0) continue;
            string key = line.Substring(0, idx).Trim();
            string value = line.Substring(idx + 1).TrimEnd('\r', '\n');
            env[key] = value;
        }

        if (!env.ContainsKey("INCLUDE") || !env.ContainsKey("LIB"))
        {
            throw new Exception(
                "vcvarsall.bat did not produce the expected MSVC environment variables (INCLUDE, LIB). " +
                "Something went wrong while capturing the VS Developer environment.");
        }

        return env;
    }

    private static async Task BuildHarfbuzzAsync(
        Flavor flavor, string srcDir, string buildDir, Dictionary<string, string> vsEnv)
    {
        Console.WriteLine($"[FreetypeStack] Building Harfbuzz + Freetype ({flavor.Name}, /{flavor.Vscrt.ToUpper()}) -> {buildDir}");

        void ApplyEnv(IDictionary<string, string?> target)
        {
            foreach (var kv in vsEnv) target[kv.Key] = kv.Value;
        }

        if (!Directory.Exists(buildDir))
        {
            // Harfbuzz' meson.build pulls Freetype in as a subproject via
            // harfbuzz/subprojects/freetype2.wrap, which fetches VER-2-11-0 from GitLab the
            // first time (and caches it thereafter). That gives us a separately linkable
            // libfreetype.a as a side-effect of the Harfbuzz build.
            await RunAsync("meson",
                $"setup \"{buildDir}\" " +
                $"--buildtype={flavor.Buildtype} " +
                "--default-library=static " +
                $"-Db_vscrt={flavor.Vscrt} " +
                "--wrap-mode=default " +
                "-Dfreetype=enabled " +
                "-Dglib=disabled " +
                "-Dgobject=disabled " +
                "-Dcairo=disabled " +
                "-Dchafa=disabled " +
                "-Dicu=disabled " +
                "-Dtests=disabled " +
                "-Ddocs=disabled",
                workingDirectory: srcDir,
                configureEnvironment: ApplyEnv);
        }

        await RunAsync("meson", $"compile -C \"{buildDir}\"",
            workingDirectory: srcDir,
            configureEnvironment: ApplyEnv);
    }

    private static async Task BuildFribidiAsync(
        Flavor flavor, string srcDir, string buildDir, Dictionary<string, string> vsEnv)
    {
        Console.WriteLine($"[FreetypeStack] Building Fribidi ({flavor.Name}, /{flavor.Vscrt.ToUpper()}) -> {buildDir}");

        void ApplyEnv(IDictionary<string, string?> target)
        {
            foreach (var kv in vsEnv) target[kv.Key] = kv.Value;
        }

        if (!Directory.Exists(buildDir))
        {
            // Fribidi is LGPL 2.1+, so we ship it as a DLL + import-lib to stay on the right
            // side of the LGPL's dynamic-linking exception.
            await RunAsync("meson",
                $"setup \"{buildDir}\" " +
                $"--buildtype={flavor.Buildtype} " +
                "--default-library=shared " +
                $"-Db_vscrt={flavor.Vscrt} " +
                "-Ddeprecated=false " +
                "-Dtests=false " +
                "-Ddocs=false",
                workingDirectory: srcDir,
                configureEnvironment: ApplyEnv);
        }

        await RunAsync("meson", $"compile -C \"{buildDir}\"",
            workingDirectory: srcDir,
            configureEnvironment: ApplyEnv);
    }

    private static void CopyArtefacts(string hbBuildDir, string fribidiBuildDir, string distDir)
    {
        Console.WriteLine($"[FreetypeStack] Copying artefacts to {distDir}");

        // Static libs coming out of the Harfbuzz build tree. Meson names them .a on Windows
        // when default_library=static; the file format is MSVC-compatible AR so renaming
        // to .lib is enough for Beef's linker.
        Copy(Path.Combine(hbBuildDir, "src", "libharfbuzz.a"),
             Path.Combine(distDir, "harfbuzz.lib"));
        Copy(Path.Combine(hbBuildDir, "subprojects", "freetype", "libfreetype.a"),
             Path.Combine(distDir, "freetype.lib"));
        Copy(FindVersionedSubprojectLib(hbBuildDir, "libpng", "libpng16.a"),
             Path.Combine(distDir, "png16.lib"));
        Copy(FindVersionedSubprojectLib(hbBuildDir, "zlib", "libz.a"),
             Path.Combine(distDir, "z.lib"));

        // Fribidi: shared lib + import lib.
        Copy(Path.Combine(fribidiBuildDir, "lib", "fribidi.lib"),
             Path.Combine(distDir, "fribidi.lib"));
        Copy(Path.Combine(fribidiBuildDir, "lib", "fribidi-0.dll"),
             Path.Combine(distDir, "fribidi-0.dll"));
    }

    private static void Copy(string src, string dst)
    {
        if (!File.Exists(src))
            throw new FileNotFoundException($"Expected build artefact not found: {src}");

        File.Copy(src, dst, overwrite: true);
    }

    /// <summary>
    /// Subproject directories under a Meson build tree are named with an embedded version
    /// (e.g. <c>libpng-1.6.37</c>) that drifts whenever the wrap files are updated upstream,
    /// so we locate by prefix instead of hard-coding the version.
    /// </summary>
    private static string FindVersionedSubprojectLib(string buildDir, string dirPrefix, string fileName)
    {
        string subprojectsDir = Path.Combine(buildDir, "subprojects");
        if (!Directory.Exists(subprojectsDir))
            throw new DirectoryNotFoundException($"Expected Meson subprojects dir missing: {subprojectsDir}");

        foreach (string dir in Directory.EnumerateDirectories(subprojectsDir))
        {
            string name = Path.GetFileName(dir);
            if (!name.StartsWith(dirPrefix, StringComparison.OrdinalIgnoreCase)) continue;

            string candidate = Path.Combine(dir, fileName);
            if (File.Exists(candidate))
                return candidate;
        }

        throw new FileNotFoundException(
            $"Could not find {fileName} under any subprojects/{dirPrefix}* directory in {buildDir}");
    }
}
