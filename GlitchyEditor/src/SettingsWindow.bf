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
			public StringView Tooltip;

			public this(StringView name, StringView fieldName, Object settingsObject, StringView tooltip)
			{
				Name = new String(name);
				FieldName = new String(fieldName);
				SettingsObject = settingsObject;
				Tooltip = tooltip;
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

			public void AddSetting(StringView name, StringView fieldName, Object settingsObject = null, StringView tooltip = "")
			{
				Binding binding = new .(name, fieldName, settingsObject ?? SettingsObject, tooltip);
				_bindings.Add(binding);
			}
		}

		Settings _settings;

		bool _settingsChanged = false;

		private Dictionary<String, Category> _categories = new .() ~ DeleteDictionaryAndValues!(_);

		public this()
		{
			_open = false;

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
					AddSetting(settingInfo.Category, settingInfo.Name, field.Name, container, settingInfo.Tooltip);
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

		void AddSetting(String categoryName, String name, StringView fieldName, Object container, StringView tooltip)
		{
			Category category = AddCategory(categoryName);

			category.AddSetting(name, fieldName, container, tooltip);
		}

		protected override void InternalShow()
		{
			ImGui.Begin("Settings", &_open, .NoDocking);
			defer ImGui.End();

			// Leave room for 1 line below us
			ImGui.BeginChild("item view", ImGui.Vec2(0, -ImGui.GetFrameHeightWithSpacing()));

			ImGui.BeginTabBar("##Tabs");

			for (Category category in _categories.Values)
			{
				if (ImGui.BeginTabItem(category.Header))
				{
					ShowCategory(category);
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

		private void ShowCategory(Category category)
		{
			if (ImGui.BeginTable("SettingsTable", 2, .SizingFixedFit | .RowBg))
			{
				ImGui.TableSetupColumn("Settings");
				ImGui.TableSetupColumn("Values", .WidthStretch);

				ImGui.TableNextRow();
				ImGui.TableSetColumnIndex(1);
				ImGui.PushItemWidth(ImGui.GetContentRegionAvail().x);

				for (Binding setting in category._bindings)
				{
					ImGui.TableNextRow();

                	ImGui.TableNextColumn();

					// Name of setting
					ImGui.TextUnformatted(setting.Name);
					
					if (!setting.Tooltip.IsWhiteSpace)
						ImGui.AttachTooltip(setting.Tooltip);

					ImGui.TableNextColumn();

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
					case typeof(bool):
						let value = GetSettingValue!<bool>();

						if (!ImGui.Checkbox(scope $"##{setting.Name}", &value))
							break;

						SetSettingValue!(value);

						_settingsChanged = true;
					case typeof(int32):
						int32 value = GetSettingValue!<int32>();

						if (!ImGui.InputInt(scope $"##{setting.Name}", &value))
							break;

						SetSettingValue!(value);

						_settingsChanged = true;
					case typeof(String):
						String value = GetSettingValue!<String>();

						char8[256] buffer = .();

						value?.CopyTo(buffer);

						if (ImGui.InputText(scope $"##{setting.Name}", &buffer, buffer.Count))
						{
							if (value != null)
								value..Clear().Append(&buffer);
							else
								SetSettingValue!(new String(&buffer));

							_settingsChanged = true;
						}
					}
					
					/*if (fieldInfo.FieldType.IsEnum)
					{
						uint64 enumValue = 0;

						fieldInfo.GetValueReference(setting.SettingsObject);

						// Assign value
						switch (fieldInfo.FieldType.Size)
						{
						case 1: enumValue = *(uint8*)&enumValue;
						case 2: *(uint16*)&enumValue = *(uint16*)&enumValue;
						case 4: *(uint32*)&enumValue = *(uint32*)&enumValue;
						case 8: *(uint64*)&enumValue = *(uint64*)&enumValue;
						}

						bool found = false;
						for (var field in valType.GetFields())
						{
							if (field.[Friend]mFieldData.mFlags.HasFlag(.EnumCase) &&
								*(int64*)&field.[Friend]mFieldData.[Friend]mData == valueData)
							{
								writer.Enum(field.Name);
								found = true;
								break;
							}
						}

						// Find field on enum
						bool found = false;
						for (var field in valType.GetFields())
							if (field.[Friend]mFieldData.mFlags.HasFlag(.EnumCase)
								&& name == field.Name)
							{
								// Add value of enum case to current enum value
								enumValue |= *(int64*)&field.[Friend]mFieldData.[Friend]mData;
								found = true;
								break;
							}

						if (!found)
							Error!("Enum case not found", reader, valType);


						uint64 value = 0;
						StringView selectedValue;
						
						for (FieldInfo enumField in fieldInfo.FieldType.GetFields())
						{
							if (enumField.[Friend]mFieldData.mFlags.HasFlag(.EnumCase))
							{
								hasCaseData = true;

								if (name == enumField.Name)
								{
									unionPayload = ValueView(enumField.FieldType, val.dataPtr);
									
									foundCase = true;
									break;
								}
								
								unionDiscrIndex++;
							}
							else if (enumField.[Friend]mFieldData.mFlags.HasFlag(.EnumDiscriminator))
							{
								let discrType = enumField.FieldType;
								Debug.Assert(discrType.IsInteger);
								discrVal = ValueView(discrType, (uint8*)val.dataPtr + enumField.[Friend]mFieldData.mData);
							}
						}

						ImGui.BeginCombo(scope $"##{setting.Name}", null);

						for (var v in Enum.GetValues(fieldInfo.FieldType))
						{

						}

						ImGui.EndCombo();

						/*// Find field on enum
						bool found = false;
						for (var field in valType.GetFields())
							if (field.[Friend]mFieldData.mFlags.HasFlag(.EnumCase)
								&& name == field.Name)
							{
								// Add value of enum case to current enum value
								enumValue |= *(int64*)&field.[Friend]mFieldData.[Friend]mData;
								found = true;
								break;
							}*/
					}*/
				}
				
				ImGui.EndTable();
			}
		}
	}
}