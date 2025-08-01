using System;
using ImGui;
using System.Collections;
using System.IO;
using Bon;

namespace GlitchyEngine
{
	interface ISettings
	{
		void Apply();
	}

	/// Fields with this Attribute will be scanned for Settings.
	[AttributeUsage(.Field, .ReflectAttribute)]
	struct SettingContainerAttribute : Attribute
	{
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

	[Reflect, BonTarget]
	class Settings
	{
#if IMGUI
		[SettingContainer, BonInclude]
		public readonly ImGuiSettings ImGuiSettings = new .() ~ delete _;
#endif
		[BonIgnore]
		public Event<EventHandler> OnApplySettings = .() ~ _.Dispose();

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

			OnApplySettings.Invoke(this, .Empty);

			/*for (let settings in _userSettings)
			{
				settings.Apply();
			}*/
		}

		public static void Load()
		{
			Settings settings = Application.Get().Settings;

			if (!File.Exists("./settings.bon"))
			{
				settings.Save();
			}

			var result = Bon.DeserializeFromFile(ref settings, "./settings.bon");

			if (result case .Err)
				Log.EngineLogger.Error("Failed to deserialze settings.");

			Application.Get().Settings.Apply();
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
			Application.Instance.[Friend]_imGuiLayer.SettingsInvalid = true;
		}
	}
#endif
}