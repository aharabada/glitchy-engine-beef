using System;
using GlitchyEngine;
using Bon;
using GlitchyEditor;
using GlitchyEditor.CodeEditors;
using System.Collections;
using System.IO;
using System.Diagnostics;
using System.Threading;

namespace GlitchyEngine
{
	extension Settings
	{
#if DEBUG
		[SettingContainer, BonInclude]
		public readonly DevSettings DevSettings = new .() ~ delete _;
#endif
		
		[SettingContainer, BonInclude]
		public readonly EditorSettings EditorSettings = new .() ~ delete _;
		
		[SettingContainer, BonInclude]
		public readonly ScriptSettings ScriptSettings = new .() ~ delete _;
		
		protected override void RegisterEventListeners()
		{
#if DEBUG
			OnApplySettings.Add(new (s, e) => DevSettings.Apply());
#endif
			OnApplySettings.Add(new (s, e) => EditorSettings.Apply());
			OnApplySettings.Add(new (s, e) => ScriptSettings.Apply());
		}
	}
}

namespace GlitchyEditor;

#if DEBUG
[Reflect]
class DevSettings
{
	[Setting("Dev", "Use ScriptCore csproj", "If enabled the Editor will include the csproj of the ScriptCore instead of the compiled dll."), BonInclude]
	public bool UseScriptCoreDll = true;

	public void Apply()
	{

	}
}
#endif

[Reflect]
enum ScriptIde
{
	Rider,
	VisualStudio
}

[Reflect]
class ScriptSettings
{
	[Setting("Tools", "Visual Studio path", "The path of Visual Studio's \"devenv.exe\""), BonInclude]
	public String VisualStudioPath ~ delete _;

	[Setting("Tools", "Rider path", "The path to JetBrains Rider IDE (rider64.exe)"), BonInclude]
	public String RiderPath ~ delete _;
	
	[Setting("Tools", "IDE", "The IDE that will be used to open scripts for editing."), BonInclude]
	public ScriptIde SelectedIde;

	private bool _lookedForVs = false;
	private bool _lookedForRider = false;

	public void Apply()
	{
#if BF_PLATFORM_WINDOWS
		if (!_lookedForVs && String.IsNullOrWhiteSpace(VisualStudioPath))
		{
			FindVisualStudio();
		}
#endif

		if (!_lookedForRider && String.IsNullOrWhiteSpace(RiderPath))
		{
			FindRider();
		}
	}

	void FindVisualStudio()
	{
		_lookedForVs = true;

		Thread thread = new Thread(new => FindVisualStudioImpl);
		thread.AutoDelete = true;
		thread.IsBackground = true;
		thread.Start();
	}

	void FindVisualStudioImpl()
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
		processInfo.SetArguments("-latest -requires Microsoft.VisualStudio.Workload.NativeDesktop -property productPath");

		let process = scope SpawnedProcess();
		if (process.Start(processInfo) case .Ok)
		{
			FileStream outputStream = scope FileStream();
			process.AttachStandardOutput(outputStream);
	
			process.WaitFor(1000);
	
			if (VisualStudioPath == null)
			{
				VisualStudioPath = new String();
			}
			else
			{
				VisualStudioPath.Clear();
			}
			
			if (outputStream.Length > 0)
			{
				StreamReader streamReaderOut = scope StreamReader(outputStream, null, false, 4096);
				streamReaderOut.ReadToEnd(VisualStudioPath).IgnoreError();

				VisualStudioPath.Trim();

				if (File.Exists(VisualStudioPath))
				{
					Log.EngineLogger.Info($"Located Visual Studio: {VisualStudioPath}");

					Apply();
				}
				else
				{
					Log.EngineLogger.Error($"Failed to find Visual Studio. vswhere output: \n{VisualStudioPath}\n\n");
					VisualStudioPath.Clear();
				}
			}
		}
		else
		{
			Log.EngineLogger.Error("Couldn't automatically determine location of Visual Studio: Failed to launch vswhere.exe");
		}
	}

	void FindRider()
	{
		_lookedForRider = true;

		Thread thread = new Thread(new => FindRiderImpl);
		thread.AutoDelete = true;
		thread.IsBackground = true;
		thread.Start();
	}

	void FindRiderImpl()
	{
		List<RiderInstallInfo> installs = new .();

		RiderPathLocator.CollectAllPaths(installs);

		// Don't touch the settings or the log from this thread: the editor's log window appends to
		// a plain List and isn't synchronized, so logging from here corrupts it.
		Application.Instance.InvokeOnMainThread(new () => ReportRiderInstalls(installs));
	}

	/// Logs the located Rider installations and stores the newest one in RiderPath.
	/// @param installs The located installations, newest first. Takes ownership.
	bool ReportRiderInstalls(List<RiderInstallInfo> installs)
	{
		defer { DeleteContainerAndItems!(installs); }

		for (RiderInstallInfo install in installs)
		{
			Log.EngineLogger.Info($"Found Rider {install.Version} at \"{install.Path}\" ({install.InstallType})");
		}

		if (installs.IsEmpty)
		{
			Log.EngineLogger.Warning("Couldn't automatically determine location of Rider: No installation found.");
			return true;
		}

		// CollectAllPaths sorts the installations, newest first.
		RiderInstallInfo newestInstall = installs.Front;

		if (RiderPath == null)
		{
			RiderPath = new String(newestInstall.Path);
		}
		else
		{
			RiderPath..Clear().Append(newestInstall.Path);
		}

		Log.EngineLogger.Info($"Located Rider: {RiderPath}");

		Apply();

		return true;
	}
}

[Reflect]
class EditorSettings
{
	[Setting("Editor", "Switch to Player on play", "If checked the editor will automatically switch to the \"Play\" window after starting the game."), BonInclude]
	public bool SwitchToPlayerOnPlay = true;

	[Setting("Editor", "Switch to Player on simulate", "If checked the editor will automatically switch to the \"Play\" window after starting the simulation."), BonInclude]
	public bool SwitchToPlayerOnSimulate = true;
	
	[Setting("Editor", "Switch to Player on continue", "If checked the editor will automatically switch to the \"Play\" window when the game is continued after pausing."), BonInclude]
	public bool SwitchToPlayerOnResume = false;

	[Setting("Editor", "Switch to Editor on stop", "If checked the editor will automatically switch to the \"Editor\" window after stopping the game."), BonInclude]
	public bool SwitchToEditorOnStop = true;
	
	[Setting("Editor", "Switch to Editor on pause", "If checked the editor will automatically switch to the \"Editor\" window when the game is being paused."), BonInclude]
	public bool SwitchToEditorOnPause = false;
	
	[Setting("Editor", "Clear log on play", "If checked the message log will be cleared when the play-mode is entered."), BonInclude]
	public bool ClearLogOnPlay = true;

	[BonInclude]
	private List<String> _recentProjects ~ DeleteContainerAndItems!(_);

	/// Gets or sets the path of the Project that was last open.
	public StringView LastOpenedProject
	{
		get
		{
			if (_recentProjects == null || _recentProjects.Count == 0)
				return "";

			return _recentProjects[0];
		}
		set
		{
			if (_recentProjects == null)
				_recentProjects = new List<String>();

			// Remove duplicates
			for (var entry in _recentProjects)
			{
				if (entry == value)
				{
					delete entry;
					@entry.Remove();
				}
			}

			_recentProjects.Insert(0, new String(value));

			if (_recentProjects.Count > 10)
			{
				// We only store 10 entries, delete the rest
				for (int i = 10; i < _recentProjects.Count; i++)
				{
					delete _recentProjects[i];
				}

				_recentProjects.Count = 10;
			}
		}
	}

	public List<String> RecentProjects => _recentProjects;

	public void Apply()
	{
	}
}