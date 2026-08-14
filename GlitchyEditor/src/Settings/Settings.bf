using System;
using ImGui;
using System.Collections;
using System.IO;
using Bon;
using GlitchyEngine;
using System.Threading;
using System.Linq;

using static GlitchyEditor.SettingsWindow;

namespace GlitchyEditor.Settings;

interface ISettings
{
	void Apply();
}

function void RenderMethod(SettingsWindow.Category category);
function void FieldRenderMethod(SettingsWindow.Binding setting);

/// Fields with this Attribute will be scanned for Settings.
[AttributeUsage(.Field, .ReflectAttribute)]
struct SettingContainerAttribute : Attribute
{
	public RenderMethod RenderMethod;
}

enum SettingEditor
{
	case Default;
	case Path;//(bool MultiSelect, bool OpenFolderDialog, StringView Filter);
}

/// Fields with this Attribute will be exposed as settings.
[AttributeUsage(.Field, .ReflectAttribute)]
struct SettingAttribute : Attribute
{
	public String Category;
	public String Name;
	public String Tooltip;
	public SettingEditor EditorMode;

	public this(String category, String name, String tooltip = "", SettingEditor editorMode = .Default)
	{
		Category = category;
		Name = name;
		Tooltip = tooltip;
		EditorMode = editorMode;
	}
}

/// Fields with this Attribute will be exposed as settings.
[AttributeUsage(.Method, .ReflectAttribute | .AlwaysIncludeTarget)]
struct CustomSettingRendererAttribute : Attribute
{
	public String Category;

	public this(String category)
	{
		Category = category;
	}
}

[Reflect, BonTarget]
class Settings
{
	private bool _areFromDisk = false;

	public bool AreFromDisk => _areFromDisk;

#if IMGUI
	[SettingContainer, BonInclude]
	public readonly ImGuiSettings ImGuiSettings = new .() ~ delete _;
#endif
	[BonIgnore]
	public Event<EventHandler> OnApplySettings = .() ~ _.Dispose();

#if DEBUG
	[SettingContainer, BonInclude]
	public readonly DevSettings DevSettings = new .() ~ delete _;
#endif

	[SettingContainer, BonInclude]
	public readonly EditorSettings EditorSettings = new .() ~ delete _;

	[SettingContainer, BonInclude]
	public readonly ScriptSettings ScriptSettings = new .() ~ delete _;

	/*
	[BonInclude]
	private List<ISettings> _userSettings ~ ClearAndDeleteItems!(_);
	*/

	public this()
	{
		/*List<ISettings> userSettings = append .();
		_userSettings = userSettings;*/
		RegisterEventListeners();
	}

	protected virtual void RegisterEventListeners()
	{

	}

	public void Apply()
	{
#if IMGUI
		ImGuiSettings.Apply();
#endif

#if DEBUG
		DevSettings.Apply();
#endif
		EditorSettings.Apply();
		ScriptSettings.Apply();

		OnApplySettings.Invoke(this, .Empty);

		/*for (let settings in _userSettings)
		{
			settings.Apply();
		}*/
	}

	public static void Load()
	{
		Settings settings = EditorApp.Instance.Settings;

		if (!File.Exists("./settings.bon"))
		{
			settings.Save();
		}

		var result = Bon.DeserializeFromFile(ref settings, "./settings.bon");

		settings._areFromDisk = true;

		if (result case .Err)
			Log.EngineLogger.Error("Failed to deserialze settings.");

		settings.Apply();
	}

	public void Save()
	{
		gBonEnv.serializeFlags |= .Verbose;
		Bon.SerializeIntoFile(this, "./settings.bon");
	}

	/*
	/// Registers a instance of a settings interface. Note: Takes ownership of the instance.
	public void RegisterUserSettings(ISettings settings)
	{
		_userSettings.Add(settings);
	}

	public T GetUserSettings<T>() where T : ISettings, class
	{
		for (let v in _userSettings)
		{
			if (v is T)
			{
				return (T)v;
			}
		}

		return null;
	}*/
}

#if IMGUI
[Reflect]
class ImGuiSettings
{
	[Setting("UI", "Font Size"), BonInclude]
	public int32 FontSize = 14;

	[Setting("UI", "Font name"), BonInclude]
	public readonly String FontName = new .("Fonts/CascadiaCode.ttf") ~ delete _;

	public void Apply()
	{
		EditorApp.Instance.[Friend]_imGuiLayer?.SettingsInvalid = true;
	}
}
#endif

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
class IdeInstallation
{
	[BonInclude]
	public ScriptIde Ide;
	[BonInclude]
	private String _path ~ delete _;
	[BonInclude]
	private String _name ~ delete _;

	public StringView Path
	{
		get => _path;
		set => String.NewOrSet!(_path, value);
	}

	public StringView Name
	{
		get => _name;
		set => String.NewOrSet!(_name, value);
	}

	[BonInclude]
	public bool IsAutoDetected;
	// TODO: allow custom IDEs? We then need something like "'Open Project' command line", "'Open file' command line" and "'Open file at location' command line"
	// This would however be quite complicated to implement well, when looking at how different Visual Studio and Rider already are.
}

[Reflect]
class ScriptSettings
{
	[BonInclude]
	private List<IdeInstallation> _ideInstallations = new .() ~ DeleteContainerAndItems!(_);

	// TODO: It's probably overkill to have a lock for the ide list.
	// If we cared enough about multi threading, InvokeOnMainThread would probably be enough.
	private Monitor _ideInstallationsLock = new .() ~ delete _;

	[BonInclude]
	private String _activeIdePath = new String() ~ delete _;

	public IdeInstallation ActiveIde => _ideInstallations.Where((i) => i.Path == _activeIdePath).FirstOrDefault();

	private bool _lookedForVs = false;
	private bool _lookedForRider = false;

	/// Enters the lock and gets the list of Ide installations.
	public Monitor.MonitorLockInstance EnterAndGetIdeInstallations(out List<IdeInstallation> ideInstallations)
	{
		let lock = _ideInstallationsLock.Enter();
		ideInstallations = _ideInstallations;
		return lock;
	}

	public void Apply()
	{
		if (ActiveIde == null)
		{
			using (EnterAndGetIdeInstallations(let ideInstallations))
			{
				// If no IDE is selected, just select the first one
				if (ideInstallations?.Count > 0)
				{
					_activeIdePath.Set(ideInstallations.Front.Path);
				}
			}
		}
	}

	[CustomSettingRenderer("Tools")]
	public bool RenderUI(SettingsWindow.Category category)
	{
		bool settingsChanged = false;

		ImGui.Text("IDE:");

		if (ImGui.BeginCombo("##ide", ActiveIde?.Name.ToScopeCStr!()))
		{
			using (EnterAndGetIdeInstallations(let installations))
			{
				for (let ide in installations)
				{
					if (ImGui.Selectable(ide.Name.ToScopeCStr!()) && ActiveIde != ide)
					{
						_activeIdePath.Set(ide.Path);
						settingsChanged = true;
					}

					ImGui.AttachTooltip(ide.Path);
				}
			}

			ImGui.EndCombo();
		}

		if (ImGui.Button("Detect IDEs..."))
		{
			//BackgroundTask task = new BackgroundTask();

			EditorApp.Instance.BackgroundTaskManager.StartBackgroundTask(new DetectIDEsBackgroundTask(this));
		}

		return settingsChanged;
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
