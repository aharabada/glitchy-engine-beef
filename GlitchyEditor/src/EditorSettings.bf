using System;
using GlitchyEngine;
using Bon;
using GlitchyEditor;
using System.Collections;
using System.IO;
using System.Diagnostics;

namespace GlitchyEngine
{
	extension Settings
	{
		[SettingContainer, BonInclude]
		public readonly EditorSettings EditorSettings = new .() ~ delete _;
		
		[SettingContainer, BonInclude]
		public readonly ScriptSettings ScriptSettings = new .() ~ delete _;
		
		protected override void RegisterEventListeners()
		{
			OnApplySettings.Add(new (s, e) => EditorSettings.Apply());
			OnApplySettings.Add(new (s, e) => ScriptSettings.Apply());
		}
	}
}

namespace GlitchyEditor;

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

	public void Apply()
	{
		if (String.IsNullOrWhiteSpace(VisualStudioPath))
		{
			// TODO: Do later
			//FildVisualStudio();
		}
	}

	void FildVisualStudio()
	{
		// TODO: Find devenv.exe ourselves
		String exeFile = scope .();
		Environment.GetExecutableFilePath(exeFile);

		String exeDirectory = scope .();
		Path.GetDirectoryPath(exeFile, exeDirectory);

		String vsWherePath = scope .();
		Path.Combine(vsWherePath, exeDirectory, "vswhere.exe");

		ProcessStartInfo processInfo = scope .();
		processInfo.SetFileName(vsWherePath);
		processInfo.UseShellExecute = true;
		// Find the installation path of the latest visual studio
		processInfo.SetArguments("-latest -property installationPath");
		processInfo.RedirectStandardOutput = true;
		//processInfo.CreateNoWindow = true;
		
		String vsInstallDirectory = scope .();

		{
			
			Windows.FileHandle h = Windows.CreateFileA("vspath.tmp",
			    Windows.GENERIC_WRITE,
			    .ReadWrite,
			    null,
			    .Create,
			    128,
			    .InvalidHandle);

			//Windows.FileHandle h = (.)Windows.CreateFileMappingA(.InvalidHandle, null, 0x40, 4096, 4096, null);

			Windows.ProcessInformation pi = .();
			Windows.StartupInfo si = .();
			Windows.IntBool ret = false; 
			int32 flags = Windows.CREATE_NO_WINDOW;

			si.mCb = sizeof(Windows.StartupInfo);
			si.mFlags |= Windows.STARTF_USESTDHANDLES;
			si.mStdInput = .InvalidHandle;
			si.mStdError = .InvalidHandle;
			si.mStdOutput = h;

			char8* cmd = scope $"{vsWherePath} -latest -property installationPath";
			ret = Windows.CreateProcessA(null, cmd, null, null, true, flags, null, null, &si, &pi);

			// Wait for the process for one second
			Windows.WaitForSingleObject(pi.mProcess, 1000);

			/*if ( ret ) 
			{
			    CloseHandle(pi.hProcess);
			    CloseHandle(pi.hThread);
			    return 0;
			}*/


			/*let process = scope SpawnedProcess();
			process.AttachStandardOutput();
			process.Start(processInfo);

			while (!process.HasExited)
			{

			}

			BufferedFileStream tmpFile = scope BufferedFileStream();
			tmpFile.Open("vspath.tmp", .ReadWrite, .None, 4096, .DeleteOnClose);

			//scope SpawnedProcess().Start(processInfo);

			//tmpFile.Position = 0;

			{
				StreamReader reader = scope StreamReader(tmpFile);
				reader.ReadToEnd(vsInstallDirectory);
			}

			tmpFile.Close();*/
		}

		if (VisualStudioPath == null)
			VisualStudioPath = new String();
		else
			VisualStudioPath.Clear();

		Path.Combine(VisualStudioPath, vsInstallDirectory, "Common7/IDE/devenv.exe");
	}

#if BF_PLATFORM_WINDOWS
		void StartProgramm()
		{
			/*Windows.FileHandle h = (.)Windows.CreateFileMappingA(.InvalidHandle, null, 0x40, 4096, 4096, null);

			Windows.ProcessInformation pi = .();
			Windows.StartupInfo si = .();
			Windows.IntBool ret = false; 
			uint32 flags = Windows.CREATE_NO_WINDOW;

			si.mCb = sizeof(Windows.StartupInfo);
			si.mFlags |= Windows.STARTF_USESTDHANDLES;
			si.mStdInput = .InvalidHandle;
			si.mStdError = .InvalidHandle;
			si.mStdOutput = h;


			ret = Windows.CreateProcessA(null, cmd, NULL, NULL, TRUE, flags, NULL, NULL, &si, &pi);

			if ( ret ) 
			{
			    CloseHandle(pi.hProcess);
			    CloseHandle(pi.hThread);
			    return 0;
			}

			return -1;*/
		}
#endif
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