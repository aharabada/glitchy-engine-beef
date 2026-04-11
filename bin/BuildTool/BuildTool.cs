using System.CommandLine;
using System.Diagnostics;
using SimpleExec;
using Spectre.Console;
using static SimpleExec.Command;
using Command = System.CommandLine.Command;

namespace BuildTool;

class BuildInfo
{
    public WorkingDirectoryHistory WorkingDirectory;
    public bool ForceRebuild;
    public bool BuildDebug;
    public bool BuildRelease;

    public BuildInfo(WorkingDirectoryHistory workingDirectory, bool forceRebuild, bool buildDebug, bool buildRelease)
    {
        WorkingDirectory = workingDirectory;
        ForceRebuild = forceRebuild;
        BuildDebug = buildDebug;
        BuildRelease = buildRelease;
    }
}

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
            await RunAsync("dotnet", $"build \"{projectFile}\" -c Debug");
        }

        if (buildInfo.BuildRelease)
        {
            await RunAsync("dotnet", $"build \"{projectFile}\" -c Release");
        }

        return true;
    }
}

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
}

class BeefWorkspaceModule : Module
{
    public static readonly string ModuleName = "BeefWorkspace";

    public override string Name => ModuleName;

    public override List<Type> DependencyTypes => [typeof(GlitchyEngineHelperModule)];

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

abstract class Module
{
    public abstract string Name { get; }

    public List<Module> Dependencies { get; } = new();
    public abstract List<Type> DependencyTypes { get; }

    public abstract Task<bool> Run(BuildInfo buildInfo);
}

class Program
{
    /// <summary>
    /// Given a list of modules, returns a list with the order in which they need to be build.
    /// </summary>
    /// <param name="requestedModules">The list of modules we want to build.</param>
    /// <param name="outOrderedModules">The list will receive the modules in the order in which they need to be build.</param>
    /// <returns><see langword="true"/> if the modules have been ordered; <see langword="false"/>, if the graph could not be ordered.</returns>
    private static bool ComputeBuildOrder(List<Module> requestedModules, List<Module> outOrderedModules)
    {
        Dictionary<Module, int> indegrees = new(requestedModules.Count);
        Dictionary<Module, List<Module>> dependees = new(requestedModules.Count);

        Queue<Module> queue = new Queue<Module>(requestedModules.Count);

        // Get in-degrees and put 0-degree nodes into queue
        foreach (Module module in requestedModules)
        {
            int inDegree = module.Dependencies.Count;
            indegrees[module] = inDegree;

            if (inDegree == 0)
            {
                queue.Enqueue(module);
            }
            else
            {
                foreach (Module dependency in module.Dependencies)
                {
                    if (!dependees.TryGetValue(dependency, out List<Module>? dependeeList))
                    {
                        dependees[dependency] = dependeeList = new List<Module>();
                    }

                    dependeeList.Add(module);
                }
            }
        }

        while (queue.TryDequeue(out Module? currentModule))
        {
            outOrderedModules.Add(currentModule);

            if (dependees.TryGetValue(currentModule, out List<Module>? dependeeList))
            {
                foreach (var dependee in dependeeList)
                {
                    int dependeeIndegree = --indegrees[dependee];

                    Debug.Assert(dependeeIndegree >= 0);

                    if (dependeeIndegree == 0)
                    {
                        queue.Enqueue(dependee);
                    }
                }
            }
        }

        if (outOrderedModules.Count < requestedModules.Count)
        {
            // We have a cycle and can't order the dependencies.
            return false;
        }

        return true;
    }

    static async Task<int> Main(string[] args)
    {
        List<Module> modules = [new BeefWorkspaceModule(), new GlitchyEngineHelperModule(), new ScriptCoreModule(), new SetupNethostModule(), new AllModule()];

        // Find dependencies
        foreach (Module module in modules)
        {
            foreach (Type moduleDependencyType in module.DependencyTypes)
            {
                Module dependencyInstance = modules.Single(m => moduleDependencyType.IsInstanceOfType(m));
                module.Dependencies.Add(dependencyInstance);
            }
        }

        List<Module> orderedModules = new List<Module>(modules.Count);
        if (!ComputeBuildOrder(modules, orderedModules))
        {
            throw new Exception($"Could not compute build order. Are there any cylces? Unsorted modules: {string.Join(", ", modules.Except(orderedModules).Select(m => m.Name))}");
        }

        Option<bool> debugOption = new("--debug", "-d")
        {
            Description = "Defines that the specified modules should be compiled as debug builds."
        };
        Option<bool> releaseOption = new("--release", "-r")
        {
            Description = "Defines that the specified modules should be compiled as release builds."
        };
        Option<bool> rebuildOption = new("--force-rebuild", "-f")
        {
            Description = "Defines that the specified modules should be rebuild."
        };
        Option<bool> noDependenciesOption = new("--no-dependencies", "-n")
        {
            Description = "Defines that only the specified modules are build, but not their dependencies (unless they are also specified)."
        };

        Option<DirectoryInfo> workspaceRootOption = new("--workspace", "-w")
        {
            Description = "The relative or absolute path to the root directory of the workspace. If unset, the current working directory will be used.",
            DefaultValueFactory = _ => new DirectoryInfo(Environment.CurrentDirectory)
        };
        workspaceRootOption.Validators.Add(result =>
        {
            if (result.GetValueOrDefault<DirectoryInfo>() is not DirectoryInfo workspaceRoot)
            {
                result.AddError("The workspace directory doesn't exist.");
                return;
            }

            if (!workspaceRoot.Exists)
            {
                result.AddError($"The workspace directory '{workspaceRoot.FullName}' doesn't exist.");
            }

            // Minimal sanity check: Is it actually a beef workspace? (Does BeefSpace.toml exist)
            string beefSpaceFile = Path.Combine(workspaceRoot.FullName, "BeefSpace.toml");
            if (!File.Exists(beefSpaceFile))
            {
                result.AddError($"The directory '{workspaceRoot.FullName}' doesn't seem to be a workspace. Either invoke it from the root of the workspace, or use the '--workspace' option.");
            }
        });

        Argument<string[]> modulesArgument = new("modules")
        {
            Description = "The modules to build.",
            // DefaultValueFactory = _ => [AllModule.ModuleName]
        };

        modulesArgument.Validators.Add(result =>
        {
            if (result.GetValue(modulesArgument) is string[] modulesToBuild)
            {
                foreach (string moduleToBuild in modulesToBuild)
                {
                    if (!modules.Any(m => m.Name.Equals(moduleToBuild, StringComparison.OrdinalIgnoreCase)))
                    {
                        result.AddError($"The module \"{moduleToBuild}\" doesn't exists.");
                    }
                }
            }
        });
        modulesArgument.CompletionSources.Add(completionContext =>
        {
            string[] alreadySpecifiedModules = completionContext.ParseResult.GetValue(modulesArgument) ?? [];

            return modules.Select(m => m.Name) // Get available Module names.
                .Where(moduleName => moduleName.StartsWith(completionContext.WordToComplete)) // Only take the modules that start with the word to complete.
                .Where(moduleName => !alreadySpecifiedModules.Contains(moduleName)); // Remove the modules that already are specified.
        });

        RootCommand rootCommand = new("Builds the engine and it's modules.");

        Command buildCommand = new("build",  "Builds the specified modules. At least either '--debug' or '--release' or both must be specified.");
        rootCommand.Add(buildCommand);

        buildCommand.Options.Add(debugOption);
        buildCommand.Options.Add(releaseOption);
        buildCommand.Options.Add(rebuildOption);
        buildCommand.Options.Add(noDependenciesOption);
        buildCommand.Options.Add(workspaceRootOption);
        buildCommand.Arguments.Add(modulesArgument);

        buildCommand.Validators.Add(result =>
        {
            bool buildDebug = result.GetValue(debugOption);
            bool buildRelease = result.GetValue(releaseOption);

            if (!buildDebug && !buildRelease)
            {
                result.AddError("Either \"--debug\" or \"--release\" option, or both, must be specified.");
            }
        });

        buildCommand.SetAction(parseResult =>
            BuildModules(
                orderedModules,
            parseResult.GetValue(modulesArgument)!,
            parseResult.GetValue(workspaceRootOption)!,
            parseResult.GetValue(rebuildOption),
            parseResult.GetValue(noDependenciesOption),
            parseResult.GetValue(debugOption),
            parseResult.GetValue(releaseOption)));

        Command listModulesCommand = new("list");
        rootCommand.Add(listModulesCommand);
        listModulesCommand.SetAction(result =>
        {
            Console.WriteLine("Following modules can be build:");

            foreach (Module module in modules)
            {
                Console.WriteLine(module.Name);
            }

            Console.WriteLine("Build order:");
            Console.WriteLine(string.Join(" -> ", orderedModules.Select(m => m.Name)));
        });

        ParseResult parseResult = rootCommand.Parse(args);
        return await parseResult.InvokeAsync();
    }

    private static async Task BuildModules(List<Module> allModulesOrdered, string[] moduleNamesToBuild, DirectoryInfo workspaceRoot, bool forceRebuild, bool noDependencies, bool debug, bool release)
    {
        HashSet<Module> modulesToBuild = new HashSet<Module>(allModulesOrdered.Count);

        if (moduleNamesToBuild.Length == 0)
        {
            Console.WriteLine("Building all modules.");

            modulesToBuild.UnionWith(allModulesOrdered);
        }
        else
        {
            Queue<Module> modulesToAdd = new Queue<Module>(allModulesOrdered.Where(m =>
                moduleNamesToBuild.Contains(m.Name, StringComparer.OrdinalIgnoreCase)));

            while (modulesToAdd.TryDequeue(out Module? moduleToAdd))
            {
                if (modulesToBuild.Add(moduleToAdd) && !noDependencies)
                {
                    foreach (Module dependency in moduleToAdd.Dependencies)
                    {
                        modulesToAdd.Enqueue(dependency);
                    }
                }
            }
        }

        List<Module> acutalModuleOrder = allModulesOrdered.Intersect(modulesToBuild).ToList();
        
        Console.WriteLine($"Building modules: {string.Join(", ", acutalModuleOrder.Select(m => m.Name))}");
        await Task.Delay(1000);

        Console.WriteLine($"Workspace:  {workspaceRoot.FullName}");
        BuildInfo buildInfo = new(new WorkingDirectoryHistory(workspaceRoot.FullName), forceRebuild, debug, release);

        foreach (Module module in acutalModuleOrder)
        {
            string message = $"Building module: [bold italic blue]{module.Name}[/]";
            
            Console.WriteLine();
            Console.WriteLine(new string('-', message.Length));
            AnsiConsole.MarkupLine(message);
            Console.WriteLine(new string('-', message.Length));
            Console.WriteLine();

            buildInfo.WorkingDirectory.NavigateToIndex(0);

            try
            {
                await module.Run(buildInfo);
                
                AnsiConsole.MarkupLine($"\n[green]Module [bold italic]{module.Name}[/] completed successfully.[/]\n");
            }
            catch (ExitCodeException e)
            {
                AnsiConsole.MarkupLine($"\n[bold red]Error:[/] Module [bold italic]{module.Name}[/] failed with exit code: [red]{e.ExitCode}[/]\n");

                break;
            }
        }
    }
}
