using System;
using System.Diagnostics;
using GlitchyEngine;
using System.Collections;

namespace GlitchyEditor.CodeEditors;

class RiderIdeAdapter : IIdeAdapter
{
	public static void OpenScript(StringView fileName)
	{
		OpenScript(fileName, 0);
	}

	public static void OpenScript(StringView fileName, int lineNumber)
	{
		String solutionPath = scope .();
		Editor.Instance.CurrentProject.PathInProject(solutionPath, scope $"{Editor.Instance.CurrentProject.Name}.sln");

		ProcessStartInfo startInfo = scope .();
		startInfo.SetFileName(Application.Instance.Settings.ScriptSettings.RiderPath);
		startInfo.SetArguments(scope $"{solutionPath} --line {lineNumber} {fileName}");

		scope SpawnedProcess().Start(startInfo);
	}

	public static void OpenScriptProject()
	{
		String solutionPath = scope .();
		Editor.Instance.CurrentProject.PathInProject(solutionPath, scope $"{Editor.Instance.CurrentProject.Name}.sln");

		ProcessStartInfo startInfo = scope .();
		startInfo.SetFileName(Application.Instance.Settings.ScriptSettings.RiderPath);
		startInfo.SetArguments(solutionPath);

		scope SpawnedProcess().Start(startInfo);
	}
}
