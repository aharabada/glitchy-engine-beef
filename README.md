# Glitchy Engine
A complete refocusation, reimagination and reimplementation of the world-renowned "Glitchy Engine"

## Prerequisites

To build the engine and its vendored dependencies, install the following tools on your developer machine. On Windows the commands below assume [Scoop](https://scoop.sh/) — substitute `winget`, `choco` or a manual install if you prefer.

| Tool                        | Purpose                                      | Install (Windows)                     |
|-----------------------------|----------------------------------------------|---------------------------------------|
| Visual Studio 2022          | MSVC toolchain, MSBuild, vswhere             | Installer — with the *Desktop development with C++* workload |
| .NET SDK 10                 | Builds the `bin/BuildTool` C# orchestrator, also required for scripting   | https://dotnet.microsoft.com/download |
| CMake                       | Builds `GlitchyEngineHelper` and some vendor libs | `scoop install cmake` or `winget install cmake`            |
| [Python 3](https://www.python.org/) + pip | Required by Meson and some vendor build scripts | `winget install Python.Python.3.13` (or use [uv](https://github.com/astral-sh/uv)) |
| [Meson](https://mesonbuild.com/) | Configures Freetype, Harfbuzz, Fribidi builds | `uv tool install meson` *or* `pip install --user meson` |
| [Ninja](https://ninja-build.org/) | Backend build system used by Meson      | `scoop install ninja` or `winget install Ninja-build.Ninja`                 |
| [pkg-config](https://www.freedesktop.org/wiki/Software/pkg-config/) | Resolves library metadata during Meson builds | `scoop install pkg-config` |
| Beef compiler (`beefbuild`) | Compiles the Beef workspace                  | https://www.beeflang.org/              |

The `BuildTool` (`bin/BuildTool`) orchestrates the vendor-library builds and the Beef workspace compile. To verify your environment is ready, run:

```
./bin/BuildTool.exe build list
```

You should see a list of modules (`Box2D`, `FreetypeStack`, `BeefWorkspace`, …) and the topologically-sorted build order. Running individual modules takes the form:

```
./bin/BuildTool.exe build --release FreetypeStack
```
