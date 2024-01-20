using System;
using System.Diagnostics;
using GlitchyEngine;
using System.Collections;

namespace GlitchyEditor;

class VisualStudioUtility
{
	public static bool IsRunning()
	{
		List<Process> processes = scope .();

		if (Process.GetProcesses(processes) case .Err)
		{
			Log.EngineLogger.Error("Failed to get running processes.");
			return false;
		}

		for (Process process in processes)
		{
		}

		ClearAndDeleteItems!(processes);

		return false;
	}

	public static void OpenScript(StringView fileName)
	{
		if (IsRunning())
		{
			ProcessStartInfo startInfo = scope .();
			startInfo.SetFileName(Application.Instance.Settings.ScriptSettings.VisualStudioPath);
			startInfo.SetArguments(scope $"/Edit {fileName}");

			scope SpawnedProcess().Start(startInfo);
		}
		else
		{
			ProcessStartInfo startInfo = scope .();
			startInfo.SetFileName(Application.Instance.Settings.ScriptSettings.VisualStudioPath);
			startInfo.SetArguments(scope $"/Edit {fileName}");

			scope SpawnedProcess().Start(startInfo);
		}
	}

	public static void OpenScript(StringView fileName, int lineNumber)
	{
		OpenScript(fileName);
	}

	public static void OpenScriptProject()
	{
		String solutionPath = scope .();
		Editor.Instance.CurrentProject.PathInProject(solutionPath, scope $"{Editor.Instance.CurrentProject.Name}.sln");

		ProcessStartInfo psi = scope .();
		psi.SetFileName("devenv");
		psi.SetArguments(solutionPath);

		scope SpawnedProcess().Start(psi);
	}
}
