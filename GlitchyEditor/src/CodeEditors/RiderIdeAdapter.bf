using System;
using System.Diagnostics;
using GlitchyEngine;
using System.Collections;
using System.IO;
using System.IO;
using GlitchyEditor.EditWindows;
using ImGui;
using GlitchyEditor.Settings;

namespace GlitchyEditor.CodeEditors;

class RiderIdeAdapter : IIdeAdapter
{
	private IdeInstallation _ideInstallation;

	public this(IdeInstallation ideInstallation)
	{
		Debug.Assert(ideInstallation.Ide == .Rider);

		_ideInstallation = ideInstallation;
	}

	public void OpenScript(StringView fileName, int lineNumber)
	{
		String solutionPath = scope .();
		Editor.Instance.CurrentProject.GetPathToScriptSolutionFile(solutionPath);

		ProcessStartInfo startInfo = scope .();
		startInfo.SetFileName(_ideInstallation.Path);
		startInfo.SetArguments(scope $"{solutionPath} --line {lineNumber} {fileName}");

		scope SpawnedProcess().Start(startInfo);
	}

	public void OpenScriptProject()
	{
		String solutionPath = scope .();
		Editor.Instance.CurrentProject.GetPathToScriptSolutionFile(solutionPath);

		if (!File.Exists(solutionPath))
		{
			Log.EngineLogger.Error("Could not find solution file?");
			return;
		}

		if (!File.Exists(_ideInstallation.Path))
		{
			Editor.Instance.ShowSettings();
			Editor.Instance.SettingsWindow.HighlightSetting("Tools", "Rider path");

			PopupService.Instance.ShowMessageBox("Rider not found.",
				"The rider path could not be found. Please select the correct path.");

			return;
		}

		ProcessStartInfo startInfo = scope .();
		startInfo.SetFileName(_ideInstallation.Path);
		startInfo.SetArguments(solutionPath);

		scope SpawnedProcess().Start(startInfo);
	}
}

