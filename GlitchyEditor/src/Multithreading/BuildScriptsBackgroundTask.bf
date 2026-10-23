using GlitchyEngine;
using System.Collections;
using GlitchyEditor.CodeEditors;
using System.IO;
using System;
using System.Diagnostics;
using ImGui;
using GlitchyEditor.Multithreading;
using GlitchyEngine.Scripting;
using GlitchyEditor.Settings;
using System.Threading;

namespace GlitchyEditor.Multithreading;

class BuildScriptsBackgroundTask : BackgroundTask
{
	private bool _isAborting = false;

	private Project _project;
	private bool _releaseBuild;
	private StringView _dotnetPath;

	private String _buildLog = new .() ~ delete _;

	private SpawnedProcess _process ~ delete _;

	public this(StringView dotnetPath, Project project, bool releaseBuild)
	{
		_dotnetPath = dotnetPath;
		_project = project;
		_releaseBuild = releaseBuild;
	}

	public override RunResult Run()
	{
		return BuildScripts();
	}

	public override void OnRenderPopup()
	{
		if (ImGui.Begin(!_isAborting ? "Compiling scripts..." : "Aborting compilation...", null, .NoDocking | .NoCollapse | .Modal | .NoResize | .AlwaysAutoResize))
		{
			if (ImGui.BeginChild("##BuildLog", .(550, ImGui.GetTextLineHeightWithSpacing() * 6), .None, .HorizontalScrollbar))
			{
			    ImGui.TextUnformatted(_buildLog);
			}

			if (ImGui.GetScrollY() >= ImGui.GetScrollMaxY())
				ImGui.SetScrollHereY(1.0f);

			ImGui.EndChild();

			if (ImGui.Button("Cancel"))
			{
				_isAborting = true;

				_process.Kill();
			}

			ImGui.End();
		}
	}
	
	private RunResult BuildScripts()
	{
		RunResult result;

		Log.EngineLogger.Info($"Building Scripts ({(_releaseBuild ? "Release" : "Debug")})...");

		String exeFile = scope .();
		Environment.GetExecutableFilePath(exeFile);

		String exeDirectory = scope .();
		Path.GetDirectoryPath(exeFile, exeDirectory);

		ProcessStartInfo processInfo = scope .();
		processInfo.UseShellExecute = false;
		processInfo.RedirectStandardOutput = true;
		processInfo.CreateNoWindow = true;
		processInfo.SetWorkingDirectory(_project.WorkspacePath);

		processInfo.SetFileName(EditorApp.Instance.Settings.ScriptSettings.DotNetExecutablePath);

		// -sc|--self-contained... Publish the .NET runtime with your application so the runtime doesn't need to be installed on the target machine.
		// 		-> This might be useful to build the final game
		// -o|--ouput <OUTPUT_DIRECTORY>... might be useful for building the final game
		processInfo.SetArguments(scope $"build -c {(_releaseBuild ? "Release" : "Debug")}");

		_process = new SpawnedProcess();

		if (_process.Start(processInfo) case .Ok)
		{
			FileStream outputStream = scope FileStream();
			_process.AttachStandardOutput(outputStream);

			StreamReader outputReader = scope .(outputStream);
			
			while (!_process.HasExited)
			{
				outputReader.ReadToEnd(_buildLog).IgnoreError();
			}

			_process.WaitFor(-1);

			if (_isAborting)
			{
				Log.EngineLogger.Warning($"Build was aborted:\n{_buildLog}");
				result = .Abort;
			}
			else if (_process.ExitCode == 0)
			{
				Log.EngineLogger.Info($"Scripts compiled successfully:\n{_buildLog}");
				result = .Finish;
			}
			else
			{
				Log.EngineLogger.Error($"Script compilation failed:\n{_buildLog}");
				result = .Fail;
			}

			DeleteAndNullify!(_process);
		}
		else
		{
			Log.EngineLogger.Error("Failed to execute `dotnet build`");
			result = .Fail;
		}

		return result;
	}
}
