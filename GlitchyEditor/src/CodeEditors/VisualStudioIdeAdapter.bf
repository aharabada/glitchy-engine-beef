using System;
using System.Diagnostics;
using GlitchyEngine;
using System.Collections;
using GlitchyEditor.Settings;

namespace GlitchyEditor.CodeEditors;

class VisualStudioIdeAdapter : IIdeAdapter
{
	private IdeInstallation _ideInstallation;

	public this(IdeInstallation ideInstallation)
	{
		Debug.Assert(ideInstallation.Ide == .VisualStudio);

		_ideInstallation = ideInstallation;
	}

	public bool IsRunning()
	{
		List<Process> processes = scope .();

		if (Process.GetProcesses(processes) case .Err)
		{
			Log.EngineLogger.Error("Failed to get running processes.");
			return false;
		}

		for (Process process in processes)
		{
			// TODO?
		}

		ClearAndDeleteItems!(processes);

		return false;
	}

	public void OpenScript(StringView fileName, int lineNumber)
	{
		if (IsRunning())
		{
			ProcessStartInfo startInfo = scope .();
			startInfo.SetFileName(_ideInstallation.Path);
			startInfo.SetArguments(scope $"/Edit {fileName}");

			scope SpawnedProcess().Start(startInfo);
		}
		else
		{
			ProcessStartInfo startInfo = scope .();
			startInfo.SetFileName(_ideInstallation.Path);
			startInfo.SetArguments(scope $"/Edit {fileName}");

			scope SpawnedProcess().Start(startInfo);
		}
	}

	public void OpenScriptProject()
	{
		String solutionPath = scope .();
		Editor.Instance.CurrentProject.GetPathToScriptSolutionFile(solutionPath);

		ProcessStartInfo psi = scope .();
		psi.SetFileName(_ideInstallation.Path);
		psi.SetArguments(solutionPath);

		scope SpawnedProcess().Start(psi);
	}
}
