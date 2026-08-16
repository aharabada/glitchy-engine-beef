using System;
using System.Diagnostics;
using System.IO;
using GlitchyEngine;
using GlitchyEditor.EditWindows;
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

	public void OpenScript(StringView fileName, int lineNumber)
	{
		Open(fileName, lineNumber);
	}

	public void OpenScriptProject()
	{
		Open(null, 0);
	}

	private void Open(StringView fileName, int lineNumber)
	{
		String solutionPath = scope String();
		Editor.Instance.CurrentProject.GetPathToScriptSolutionFile(solutionPath);

		if (!File.Exists(solutionPath))
		{
			Log.EngineLogger.Error(scope $"Could not find solution file \"{solutionPath}\".");
			return;
		}

		if (!File.Exists(_ideInstallation.Path))
		{
			Editor.Instance.ShowSettings();
			Editor.Instance.SettingsWindow.HighlightSetting("Tools", "IDE");

			PopupService.Instance.ShowMessageBox("Visual Studio not found.",
				"The Visual Studio path could not be found. Please select a different IDE.");
			return;
		}

#if BF_PLATFORM_WINDOWS
		// Reuses a running Visual Studio instance that has our solution open (via EnvDTE),
		// otherwise starts a new one.
		DteOpenRequest request = new .();
		request.SolutionPath = solutionPath;
		request.DevenvPath = _ideInstallation.Path;
		request.FileName = fileName;
		request.LineNumber = lineNumber;

		DteOpenRequest.Start(request);
#else
		ProcessStartInfo startInfo = scope .();
		startInfo.SetFileName(_ideInstallation.Path);
		startInfo.SetArguments(scope $"\"{solutionPath}\"");

		scope SpawnedProcess().Start(startInfo);
#endif
	}
}
