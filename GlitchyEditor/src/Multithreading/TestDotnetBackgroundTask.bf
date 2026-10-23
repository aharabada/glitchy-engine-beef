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

namespace GlitchyEditor.Multithreading;

class TestDotnetBackgroundTask : BackgroundTask
{
	private ScriptSettings _settings;
	private Project _project;

	public enum TestResult
	{
		None,
		Ok,
		Timeout,
		FailedToExecute,
		NoSdksFound,
		TooOld
	}

	private TestResult _testResult;

	public TestResult TestResult => _testResult;

	public this(ScriptSettings settings, Project project)
	{
		_settings = settings;
		_project = project;
	}

	public override RunResult Run()
	{
		if (QueryAvailableSdks() case .Err)
		{
			return .Fail;
		}

		if (CheckMinimumVersion() case .Err)
		{
			return .Fail;
		}

		if (_project != null)
		{
			CheckProjectVersion();
		}

		_testResult = .Ok;

		return .Finish;
	}

	public override void OnRenderPopup()
	{
		if (ImGui.Begin("Testing .Net Installation...", null, .NoDocking | .NoCollapse | .Modal | .NoResize | .AlwaysAutoResize))
		{
			ImGui.Text("...");

			ImGui.End();
		}
	}
	
	private Result<void> QueryAvailableSdks()
	{
		_settings.DotNetSdks.Clear();

		Log.EngineLogger.Info("Listing .Net SDKs...");

		String exeFile = scope .();
		Environment.GetExecutableFilePath(exeFile);

		String exeDirectory = scope .();
		Path.GetDirectoryPath(exeFile, exeDirectory);

		ProcessStartInfo processInfo = scope .();
		processInfo.UseShellExecute = false;
		processInfo.RedirectStandardOutput = true;
		processInfo.CreateNoWindow = true;

		processInfo.SetFileName(_settings.DotNetExecutablePath);
		// Lists all installed sdks
		StringView argumentList = "--list-sdks";
		processInfo.SetArguments(argumentList);

		let process = scope SpawnedProcess();

		if (process.Start(processInfo) case .Ok)
		{
			FileStream outputStream = scope FileStream();
			process.AttachStandardOutput(outputStream);

			if (!process.WaitFor(1000))
			{
				Log.EngineLogger.Error($"`dotnet --list-sdks` timed out.");
				process.Kill();
				_testResult = .Timeout;
				return .Err;
			}

			StreamReader sr = scope .(outputStream);

			String line = scope .(256);
			while (sr.ReadLine(line..Clear()) case .Ok)
			{
				Log.EngineLogger.Info($"Detecting .Net SDK version from line: {line}");
				// A line for a normal verion looks like this:
				// 10.0.402 [C:\Program Files\dotnet\sdk]
				// A line for a snapshot looks like this:
				// 9.0.100-preview.7.24407.12 [C:\Program Files\dotnet\sdk]
				// A line for a release candidate looks like this:
				// 11.0.100-rc.2.26504.105 [C:\Program Files\dotnet\sdk]

				// We must have a number at the start so we can at least grab a major version.
				if (!line[0].IsDigit)
				{
					Log.EngineLogger.Error("This line doesn't appear to show an SDK version.");
					continue;
				}

				DotNetVersion detectedVersion = default;

				int indexOfSpace = line.IndexOf(' ');
				int indexOfDash = line.IndexOf('-');

				int versionNumberEnd = line.Length;

				if (indexOfDash > 0)
					versionNumberEnd = indexOfDash;
				else if (indexOfSpace > 0)
					versionNumberEnd = indexOfSpace;

				StringView versionString = line.Substring(0, versionNumberEnd);

				List<StringView> versionSplits = scope .(versionString.Split('.'));

				if (versionSplits.IsEmpty)
				{
					Log.EngineLogger.Error("Line doesn't contain a valid version number.");
					continue;
				}

				if (versionSplits.Count >= 1 && int.Parse(versionSplits[0]) not case .Ok(out detectedVersion.Major))
				{
					Log.EngineLogger.Error($"Failed to parse \"major\" part of version ({versionSplits[0]}).");
					continue;
				}

				if (versionSplits.Count >= 2 && int.Parse(versionSplits[1]) not case .Ok(out detectedVersion.Minor))
				{
					Log.EngineLogger.Error($"Failed to parse \"minor\" part of version ({versionSplits[1]}).");
					continue;
				}

				if (versionSplits.Count >= 3 && int.Parse(versionSplits[2]) not case .Ok(out detectedVersion.Patch))
				{
					Log.EngineLogger.Error($"Failed to parse \"patch\" part of version ({versionSplits[2]}).");
					continue;
				}
				
				if (indexOfDash > 0)
				{
					StringView previewString = line.Substring(indexOfDash + 1);

					int previewNumberStart = previewString.IndexOf('.') + 1;
					int secondDot = previewString.IndexOf('.', previewNumberStart);

					int previewNumber = 0;

					if (previewNumberStart > 0)
					{
						int length = previewString.Length - previewNumberStart;

						if (secondDot > 0)
						{
							length = secondDot - previewNumberStart;
						}

						StringView previewNumberString = previewString.Substring(previewNumberStart, length);

						if (int.Parse(previewNumberString) not case .Ok(out previewNumber))
						{
							Log.EngineLogger.Warning("Could not determine the preview number.");
						}
					}

					if (previewString.StartsWith("preview"))
					{
						detectedVersion.Type = .Preview(previewNumber);
					}
					else if (previewString.StartsWith("rc"))
					{
						detectedVersion.Type = .ReleaseCandidate(previewNumber);
					}
					else
					{
						detectedVersion.Type = .Unknown;
						Log.EngineLogger.Warning("Could not determine the preview-type for SDK.");
					}
				}
				else
				{
					detectedVersion.Type = .Normal;
				}

				Log.EngineLogger.Info($"Detected .Net SDK: {detectedVersion}.");

				_settings.DotNetSdks.Add(detectedVersion);
			}
		}
		else
		{
			Log.EngineLogger.Error($"Failed to execute `{_settings.DotNetExecutablePath} {argumentList}`");
			_testResult = .FailedToExecute;
			return .Err;
		}

		if (_settings.DotNetSdks.Count == 0)
		{
			_testResult = .NoSdksFound;
			return .Err;
		}

		return .Ok;
	}

	/// Checks if one of the detected SDKs is at least the minimum required dotnet version.
	private Result<void> CheckMinimumVersion()
	{
		DotNetVersion maxVersion = _settings.GetLatestInstalledDotNetVersion();

		if (maxVersion < ScriptEngine.MinDotNetVersion)
		{
			Log.EngineLogger.Error($"The latest detected .Net SDK ({maxVersion}) is older than the required minimum Version ({ScriptEngine.MinDotNetVersion}). Please install a newer .Net SDK or configure the dotnet executable in the settings.");
			_testResult = .TooOld;
			return .Err;
		}
		else
		{
			Log.EngineLogger.Info($"Latest detected .Net SDK: {maxVersion}.");

			return .Ok;
		}
	}

	/// Checks if one of the detected SDKs is at least the minimum required dotnet version for the current project.
	void CheckProjectVersion()
	{
		/*DotNetVersion maxVersion = GetMaxVersion();

		if (maxVersion < ScriptEngine.MinDotNetVersion)
		{
			Log.EngineLogger.Error($"The latest detected .Net SDK ({maxVersion}) is older than the required minimum Version ({ScriptEngine.MinDotNetVersion}). Please install a newer .Net SDK or configure the dotnet executable in the settings.");
		}
		else
		{
			Log.EngineLogger.Info($"Latest detected .Net SDK: {maxVersion}.");
		}*/
	}
}
