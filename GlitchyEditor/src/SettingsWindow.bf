using GlitchyEditor.EditWindows;
using ImGui;
using GlitchyEngine;
using System;
using System.Collections;
using System.Reflection;

namespace GlitchyEditor
{
	class SettingsWindow : EditorWindow
	{
		class Binding
		{
			public Object SettingsObject;
			public String Name ~ delete _;
			public String FieldName ~ delete _;

			public this(StringView name, StringView fieldName, Object settingsObject)
			{
				Name = new String(name);
				FieldName = new String(fieldName);
				SettingsObject = settingsObject;
			}
		}

		class Category
		{
			public List<Binding> _bindings = new .() ~ DeleteContainerAndItems!(_);

			public String Header ~ delete _;

			public Object SettingsObject;

			public this(String header)
			{
				Header = new String(header);
			}

			public void AddSetting(StringView name, StringView fieldName, Object settingsObject = null)
			{
				Binding binding = new .(name, fieldName, settingsObject ?? SettingsObject);
				_bindings.Add(binding);
			}
		}

		Settings _settings;

		bool _settingsChanged = false;

		private Dictionary<String, Category> _categories = new .() ~ DeleteDictionaryAndValues!(_);

		public this()
		{
			_settings = Application.Get().Settings;

			Create();
		}

		void Create()
		{
			ScanForSettings(_settings);

			/*for (ISettings settings in _settings.[Friend]_userSettings)
			{
				ScanForSettings(settings);
			}*/
		}

		Category AddCategory(String header)
		{
			if (_categories.TryGetValue(header, let category))
				return category;

			Category newCat = new Category(header);
			_categories.Add(newCat.Header, newCat);

			return newCat;
		}

		void ScanForSettings(Object container)
		{
			Type type = container.GetType();

			for (var field in type.GetFields())
			{
				Result<SettingAttribute> settingResult = field.GetCustomAttribute<SettingAttribute>();

				if (settingResult case .Ok(let settingInfo))
				{
					AddSetting(settingInfo.Category, settingInfo.Name, field.Name, container);
				}
				
				Result<SettingContainerAttribute> containerResult = field.GetCustomAttribute<SettingContainerAttribute>();
				
				if (containerResult case .Ok(let containerInfo))
				{
					var res = field.GetValue<Object>(container, let childContainer);

					if (res case .Err(let error))
					{
						Log.EngineLogger.Error($"Failed to get settings container. Error: {error}");

						continue;
					}

					ScanForSettings(childContainer);
				}
			}
		}

		void AddSetting(String categoryName, String name, StringView fieldName, Object container)
		{
			Category category = AddCategory(categoryName);

			category.AddSetting(name, fieldName, container);
		}

		protected override void InternalShow()
		{
			// Leave room for 1 line below us
			ImGui.BeginChild("item view", ImGui.Vec2(0, -ImGui.GetFrameHeightWithSpacing()));

			ImGui.BeginTabBar("##Tabs");

			for (Category category in _categories.Values)
			{
				if (ImGui.BeginTabItem(category.Header))
				{
					ImGui.Columns(2);
					defer ImGui.Columns(1);
					ImGui.SetColumnWidth(0, 100);

					for (Binding setting in category._bindings)
					{
						ImGui.TextUnformatted(setting.Name);

						ImGui.NextColumn();

						Type settingsObjectType = setting.SettingsObject.GetType();

						Result<FieldInfo> result = settingsObjectType.GetField(setting.FieldName);

						if (result case .Err)
						{
							ImGui.PushStyleColor(.Text, ImGui.Vec4(1f, 0f, 0f, 1f));
							ImGui.Text($"Field {setting.FieldName} not found.");
							ImGui.PopStyleColor();

							continue;
						}

						FieldInfo fieldInfo = result.Get();

						Type fieldType = fieldInfo.FieldType;

						mixin GetSettingValue<T>()
						{
							var error = fieldInfo.GetValue<T>(setting.SettingsObject, var value);

							if (error case .Err(let err))
							{
								Log.EngineLogger.Error($"Could not get value of setting {setting.FieldName}. Error: {err}");

								ImGui.PushStyleColor(.Text, ImGui.Vec4(1f, 0f, 0f, 1f));
								ImGui.Text($"Could not get value of setting {setting.FieldName}. Error: {err}");
								ImGui.PopStyleColor();

								break;
							}

							value
						}

						mixin SetSettingValue<T>(T value)
						{
							var error = fieldInfo.SetValue(setting.SettingsObject, value);

							if (error case .Err(let err))
							{
								Log.EngineLogger.Error($"Could not set value of setting {setting.FieldName}. Error: {err}");
							}
						}

						switch (fieldType)
						{
						case typeof(int32):
							int32 value = GetSettingValue!<int32>();

							if (!ImGui.InputInt(scope $"##{setting.Name}", &value))
								break;

							SetSettingValue!(value);

							_settingsChanged = true;
						case typeof(String):
							String value = GetSettingValue!<String>();

							char8[256] buffer = .();

							value.CopyTo(buffer);

							if (ImGui.InputText(scope $"##{setting.Name}", &buffer, buffer.Count))
							{
								value..Clear().Append(&buffer);

								_settingsChanged = true;
							}
						}

						ImGui.NextColumn();
					}

					ImGui.EndTabItem();
				}
			}

			ImGui.EndTabBar();

			ImGui.EndChild();

			ImGui.BeginDisabled(!_settingsChanged);

			if (ImGui.Button("Save"))
			{
				_settings.Save();
				_settings.Apply();
				_open = false;
			}

			ImGui.SameLine();

			if (ImGui.Button("Apply"))
			{
				_settings.Apply();
			}
			
			ImGui.EndDisabled();
	
			ImGui.SameLine();

			if (ImGui.Button("Cancel"))
			{
				Settings.Load();
				_open = false;
			}
		}
	}
}