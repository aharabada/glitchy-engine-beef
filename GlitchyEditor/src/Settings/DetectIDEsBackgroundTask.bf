using GlitchyEngine;
using System.Collections;
using GlitchyEditor.CodeEditors;
using System.IO;
using System;
using System.Diagnostics;
using ImGui;
using GlitchyEditor.Multithreading;

namespace GlitchyEditor.Settings;


class DetectIDEsBackgroundTask : BackgroundTask
{
	enum Stage
	{
		None,
		SearchVisualStudio,
		SearchRider
	}

	private Stage _stage = .None;

	private ScriptSettings _settings;

	public this(ScriptSettings settings)
	{
		_settings = settings;
	}

	public override RunResult Run()
	{
		// Remove all auto detected IDEs, keep manual ones
		using (_settings.EnterAndGetIdeInstallations(let installations))
		{
			for (let ide in installations)
			{
				if (ide.IsAutoDetected)
				{
					@ide.Remove();
					delete ide;
				}
			}
		}

#if BF_PLATFORM_WINDOWS
		_stage = .SearchVisualStudio;
		FindVisualStudio();
#endif

		_stage = .SearchRider;
		FindRider();

		return .Finished;
	}

	public override void OnRenderPopup()
	{
		if (ImGui.Begin("Detecting IDEs...", null, .NoDocking | .NoCollapse | .Modal | .NoResize | .AlwaysAutoResize))
		{
			if (_stage == .SearchVisualStudio)
			{
				ImGui.Text("Searching Visual Studio installations...");
			}
			else if (_stage == .SearchRider)
			{
				ImGui.Text("Searching Rider installations...");
			}

			ImGui.End();
		}
	}
	
#if BF_PLATFORM_WINDOWS
	void FindVisualStudio()
	{
		Log.EngineLogger.Info("Using vswhere.exe to search for Visual Studio...");

		String exeFile = scope .();
		Environment.GetExecutableFilePath(exeFile);

		String exeDirectory = scope .();
		Path.GetDirectoryPath(exeFile, exeDirectory);

		String vsWherePath = scope .();
		Path.Combine(vsWherePath, exeDirectory, "vswhere.exe");

		ProcessStartInfo processInfo = scope .();
		processInfo.UseShellExecute = false;
		processInfo.RedirectStandardOutput = true;
		processInfo.CreateNoWindow = true;

		processInfo.SetFileName(vsWherePath);
		// Find the installation path of the latest visual studio with an installed IDE.
		processInfo.SetArguments("-sort -requires Microsoft.VisualStudio.Component.Roslyn.LanguageServices -format text");

		let process = scope SpawnedProcess();
		if (process.Start(processInfo) case .Ok)
		{
			FileStream outputStream = scope FileStream();
			process.AttachStandardOutput(outputStream);

			process.WaitFor(1000);

			StreamReader sr = scope .(outputStream);

			IdeInstallation installation = null;

			String line = scope .(256);
			while (sr.ReadLine(line..Clear()) case .Ok)
			{
				const String InstanceIdPropertyName = "instanceId: ";
				const String ProductPathPropertyName = "productPath: ";
				const String DisplayNamePropertyName = "displayName: ";

				if (line.StartsWith(InstanceIdPropertyName))
				{
					if (installation != null)
					{
						using (_settings.EnterAndGetIdeInstallations(let installations))
						{
							installations.Add(installation);
						}
					}

					installation = new IdeInstallation();
					installation.Ide = .VisualStudio;
					installation.IsAutoDetected = true;
				}
				else if (line.StartsWith(ProductPathPropertyName))
				{
					installation.Path = line.Substring(ProductPathPropertyName.Length);
				}
				else if (line.StartsWith(DisplayNamePropertyName))
				{
					installation.Name = line.Substring(DisplayNamePropertyName.Length);
				}
			}

			if (!installation.Name.IsEmpty && !installation.Path.IsEmpty)
			{
				using (_settings.EnterAndGetIdeInstallations(let installations))
				{
					installations.Add(installation);
				}
			}
			else
			{
				delete installation;
			}
		}
		else
		{
			Log.EngineLogger.Error("Couldn't automatically determine location of Visual Studio: Failed to launch vswhere.exe");
		}
	}
#endif

	private void FindRider()
	{
		List<RiderInstallInfo> installs = scope .();

		RiderPathLocator.CollectAllPaths(installs);

		ReportRiderInstalls(installs);

		ClearAndDeleteItems!(installs);
	}

	private void ReportRiderInstalls(List<RiderInstallInfo> installs)
	{
		if (installs.IsEmpty)
		{
			Log.EngineLogger.Warning("Couldn't automatically determine location of Rider: No installation found.");
		}

		using (_settings.EnterAndGetIdeInstallations(let installations))
		{
			for (RiderInstallInfo install in installs)
			{
				Log.EngineLogger.Info($"Found Rider {install.Version} at \"{install.Path}\" ({install.InstallType})");
				IdeInstallation ide = new IdeInstallation();
				ide.IsAutoDetected = true;
				ide.Ide = .Rider;
				ide.Path = install.Path;
				ide.Name = install.Name;

				installations.Add(ide);
			}
		}
	}
}
