using ImGui;
using GlitchyEngine.World;
using System;
using GlitchyEngine.Math;
using System.Collections;
using GlitchyEngine.Renderer;
using GlitchyEngine;

namespace GlitchyEditor.EditWindows
{
	using internal GlitchyEngine.World.TransformComponent;

	class ComponentEditWindow : EditorWindow
	{
		public const String s_WindowTitle = "Components";

		private EntityHierarchyWindow _entityHierarchyWindow;

		private List<(Type, ComponentAttribute attribute)> _componentTypes = new .() ~ delete _;

		public this(EntityHierarchyWindow entityHierarchyWindow)
		{
			_entityHierarchyWindow = entityHierarchyWindow;

			for (let type in Type.Types)
			{
				if (let componentAttribute = type.GetCustomAttribute<ComponentAttribute>())
				{
					_componentTypes.Add((type, componentAttribute));
				}
			}
		}

		protected override void InternalShow()
		{
			ImGui.PushStyleVar(.WindowMinSize, ImGui.Vec2(1000, 100));

			if(!ImGui.Begin(s_WindowTitle, &_open, .None))
			{
				ImGui.PopStyleVar();
				ImGui.End();
				return;
			}
			
			if(_entityHierarchyWindow.SelectedEntities.Count == 1)
			{
				Entity entity = _entityHierarchyWindow.SelectedEntities.Front;

				ShowComponents(entity);
			}
			
			ImGui.PopStyleVar();
			ImGui.End();
		}

		private void ShowComponents(Entity entity)
		{
			ShowNameComponentEditor(entity);

			ShowComponentEditor<TransformComponent>("Transform", entity, => ShowTransformComponentEditor);
			ShowComponentEditor<CameraComponent>("Camera", entity, => ShowCameraComponentEditor, => ShowComponentContextMenu<CameraComponent>);
			ShowComponentEditor<SpriterRendererComponent>("Sprite Renderer", entity, => ShowSpriteRendererComponentEditor, => ShowComponentContextMenu<SpriterRendererComponent>);
			ShowComponentEditor<MeshRendererComponent>("Mesh Renderer", entity, => ShowMeshRendererComponentEditor, => ShowComponentContextMenu<MeshRendererComponent>);
			ShowComponentEditor<LightComponent>("Light", entity, => ShowLightComponentEditor, => ShowComponentContextMenu<LightComponent>);

			ShowAddComponentButton(entity);
		}

		private static void ShowComponentContextMenu<TComponent>(Entity entity, TComponent* component) where TComponent: struct, new
		{
			if (ImGui.Selectable("Remove Component"))
				entity.RemoveComponent<TComponent>();
		}

		private static void ShowComponentEditor<TComponent>(String header, Entity entity, function void(Entity, TComponent*) showComponentEditor, function void(Entity, TComponent*) showComponentContextMenu = null) where TComponent: struct, new
		{
			if (!entity.HasComponent<TComponent>())
				return;

			TComponent* component = entity.GetComponent<TComponent>();

			ImGui.PushID(header);

			bool nodeOpen = ImGui.TreeNodeEx(header.CStr(), .DefaultOpen | .AllowItemOverlap | .Framed | .SpanFullWidth);

			if (showComponentContextMenu != null)
			{
				ImGui.SameLine(ImGui.GetWindowContentRegionMax().x - ImGui.CalcTextSize("...").x - 2 * ImGui.GetStyle().FramePadding.x);

				if (ImGui.SmallButton("..."))
				{
					ImGui.OpenPopup("component_popup");
				}

				if (ImGui.BeginPopup("component_popup"))
				{
					showComponentContextMenu(entity, component);
					
					ImGui.EndPopup();
				}
			}

			if (nodeOpen)
			{
				showComponentEditor(entity, component);

				ImGui.TreePop();
			}

			ImGui.PopID();
		}

		private static void ShowNameComponentEditor(Entity entity)
		{
			if (!entity.HasComponent<DebugNameComponent>())
				return;

			char8[256] nameBuffer = default;

			DebugNameComponent* component = entity.GetComponent<DebugNameComponent>();

			String name = null;

			if(component != null)
			{
				name = component.DebugName;
			}
			else
			{
				name = scope:: $"Entity {entity.Handle.[Friend]Index}";
			}

			// Copy name to buffer
			Internal.MemCpy(&nameBuffer, name.Ptr, Math.Min(nameBuffer.Count, name.Length));

			if(ImGui.InputText("Name", &nameBuffer, nameBuffer.Count))
			{
				if(component == null)
				{
					component = entity.AddComponent<DebugNameComponent>();
				}

				component.DebugName.Clear();
				component.DebugName.Append(&nameBuffer);
			}
		}

		private static void ShowTransformComponentEditor(Entity entity, TransformComponent* transform)
		{
			float textWidth = ImGui.CalcTextSize("Position".CStr()).x;
			textWidth = Math.Max(textWidth, ImGui.CalcTextSize("Rotation".CStr()).x);
			textWidth = Math.Max(textWidth, ImGui.CalcTextSize("Scale".CStr()).x);

			textWidth += ImGui.GetStyle().FramePadding.x * 3.0f;

			Vector3 position = transform.Position;
			if (ImGui.EditVector3("Position", ref position, .Zero, 0.1f, textWidth))
				transform.Position = position;

			Vector3 rotationEuler = MathHelper.ToDegrees(transform.EditorRotationEuler);
			if (ImGui.EditVector3("Rotation", ref rotationEuler, .Zero, 0.1f, textWidth))
				transform.EditorRotationEuler = MathHelper.ToRadians(rotationEuler);
			
			Vector3 scale = transform.Scale;
			if (ImGui.EditVector3("Scale", ref scale, .One, 0.1f, textWidth))
				transform.Scale = scale;
		}
		
		static String[] strings = new String[]("Orthographic", "Perspective", "Perspective (Infinite)") ~ delete _;

		private static void ShowCameraComponentEditor(Entity entity, CameraComponent* cameraComponent)
		{
			ImGui.Checkbox("Primary", &cameraComponent.Primary);

			var camera = ref cameraComponent.Camera;

			String typeName = strings[camera.ProjectionType.Underlying];

			if (ImGui.BeginCombo("Projection", typeName.CStr()))
			{
				for (int i = 0; i < 3; i++)
				{
					bool isSelected = (typeName == strings[i]);

					if (ImGui.Selectable(strings[i], isSelected))
					{
						camera.ProjectionType = (.)i;
					}

					if (isSelected)
						ImGui.SetItemDefaultFocus();
				}

				ImGui.EndCombo();
			}

			if (camera.ProjectionType == .Perspective)
			{
				float fovY = MathHelper.ToDegrees(camera.PerspectiveFovY);
				if (ImGui.DragFloat("Fov Y", &fovY, 0.1f))
					camera.PerspectiveFovY = MathHelper.ToRadians(fovY);
				
				float near = camera.PerspectiveNearPlane;
				if (ImGui.DragFloat("Near", &near, 0.1f))
					camera.PerspectiveNearPlane = near;

				float far = camera.PerspectiveFarPlane;
				if (ImGui.DragFloat("Far", &far, 0.1f))
					camera.PerspectiveFarPlane = far;
			}
			else if (camera.ProjectionType == .InfinitePerspective)
			{
				float fovY = MathHelper.ToDegrees(camera.PerspectiveFovY);
				if (ImGui.DragFloat("Vertical FOV", &fovY, 0.1f))
					camera.PerspectiveFovY = MathHelper.ToRadians(fovY);
				
				float near = camera.PerspectiveNearPlane;
				if (ImGui.DragFloat("Near", &near, 0.1f))
					camera.PerspectiveNearPlane = near;
			}
			else if (camera.ProjectionType == .Orthographic)
			{
				float size = camera.OrthographicHeight;
				if (ImGui.DragFloat("Size", &size, 0.1f))
					camera.OrthographicHeight = size;
				
				float near = camera.OrthographicNearPlane;
				if (ImGui.DragFloat("Near", &near, 0.1f))
					camera.OrthographicNearPlane = near;

				float far = camera.OrthographicFarPlane;
				if (ImGui.DragFloat("Far", &far, 0.1f))
					camera.OrthographicFarPlane = far;
			}

			bool fixedAspectRatio = camera.FixedAspectRatio;
			if (ImGui.Checkbox("Fixed Aspect Ratio", &fixedAspectRatio))
				camera.FixedAspectRatio = fixedAspectRatio;

			if (fixedAspectRatio)
			{
				float aspect = camera.AspectRatio;
				if (ImGui.DragFloat("Aspect Ratio", &aspect, 0.1f))
					camera.AspectRatio = aspect;
			}
		}

		private static void ShowSpriteRendererComponentEditor(Entity entity, SpriterRendererComponent* spriteRendererComponent)
		{
			ColorRGBA spriteColor = ColorRGBA.LinearToSRGB(spriteRendererComponent.Color);
			if (ImGui.ColorEdit4("Color", ref spriteColor))
				spriteRendererComponent.Color = ColorRGBA.SRgbToLinear(spriteColor);

			ImGui.Button("Texture");

			if (ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = ImGui.AcceptDragDropPayload("CONTENT_BROWSER_ITEM");

				if (payload != null)
				{
					Log.EngineLogger.Warning("");

					StringView path = .((char8*)payload.Data, (int)payload.DataSize);

					Texture2D texture = new Texture2D(path, true);

					spriteRendererComponent.Sprite?.ReleaseRef();
					spriteRendererComponent.Sprite = texture;
				}

				ImGui.EndDragDropTarget();
			}


			ImGui.EditVector<4>("UV Transform", ref *(float[4]*)&spriteRendererComponent.UvTransform);
		}

		private static void ShowMeshRendererComponentEditor(Entity entity, MeshRendererComponent* meshRendererComponent)
		{
			// TODO: Editing material options obviously shouldn't be part of the meshrenderer-ui

			Material material = meshRendererComponent.Material;

			Effect effect = material.Effect;
			
			bool TryGetValue(Dictionary<String, Variant> parameters, String name, out Variant value)
			{
				if (parameters.TryGetValue(name, let param))
				{
					value = param;
					return true;
				}

				value = ?;

				return false;
			}

			for (let texture in effect.Textures)
			{
				//ImGui.Text(texture.key);
				ImGui.Button(texture.key);

				if (ImGui.BeginDragDropTarget())
				{
					ImGui.Payload* payload = ImGui.AcceptDragDropPayload("CONTENT_BROWSER_ITEM");

					if (payload != null)
					{
						Log.EngineLogger.Warning("");

						StringView path = .((char8*)payload.Data, (int)payload.DataSize);

						using (Texture2D newTexture = new Texture2D(path, true))
						{
							newTexture.SamplerState = SamplerStateManager.AnisotropicWrap;
							material.SetTexture(texture.key, newTexture);
						}
					}

					ImGui.EndDragDropTarget();
				}
			}

			for (let (name, arguments) in effect.[Friend]_variableDescriptions)
			{
				let variable = effect.Variables[name];
				
				bool hasPreviewName = TryGetValue(arguments, "Preview", var previewName);

				StringView displayName = hasPreviewName ? previewName.Get<String>() : name;
				
				bool hasPreviewType = TryGetValue(arguments, "Type", var previewType);

				if (hasPreviewType && previewType.Get<String>() == "Color")
				{
					Log.EngineLogger.AssertDebug(variable.Type == .Float && variable.Rows == 1);

					if (variable.Columns == 3)
					{
						material.GetVariable<Vector3>(variable.Name, var value);

						value = (Vector3)ColorRGB.LinearToSRGB((ColorRGB)value);

						if (ImGui.ColorEdit3(displayName.Ptr, *(float[3]*)&value))
						{
							value = (Vector3)ColorRGB.SRgbToLinear((ColorRGB)value);
							material.SetVariable(variable.Name, value);
						}
					}
					else if (variable.Columns == 4)
					{
						material.GetVariable<Vector4>(variable.Name, var value);
						
						value = (Vector4)ColorRGBA.LinearToSRGB((ColorRGBA)value);

						if (ImGui.ColorEdit4(displayName.Ptr, *(float[4]*)&value))
						{
							value = (Vector4)ColorRGBA.SRgbToLinear((ColorRGBA)value);
							material.SetVariable(variable.Name, value);
						}
					}
				}
				else if (variable.Type == .Float && variable.Rows == 1)
				{
					bool hasMin = TryGetValue(arguments, "Min", var min);
					bool hasMax = TryGetValue(arguments, "Max", var max);

					for (int r < variable.Rows)
					{
						switch (variable.Columns)
						{
						case 1:
							material.GetVariable<float>(variable.Name, var value);
							
							float[1] minV = hasMin ? min.Get<float[1]>() : .(float.MinValue);
							float[1] maxV = hasMax ? max.Get<float[1]>() : .(float.MaxValue);

							if (ImGui.EditVector<1>(displayName, ref *(float[1]*)&value, .(), 0.1f, 100.0f, minV, maxV))
								material.SetVariable(variable.Name, value);
						case 2:
							material.GetVariable<Vector2>(variable.Name, var value);
							
							Vector2 minV = hasMin ? min.Get<Vector2>() : .(float.MinValue);
							Vector2 maxV = hasMax ? max.Get<Vector2>() : .(float.MaxValue);
							
							if (ImGui.EditVector2(displayName, ref value, .Zero, 0.1f, 100.0f, minV, maxV))
								material.SetVariable(variable.Name, value);
						case 3:
							material.GetVariable<Vector3>(variable.Name, var value);
							
							Vector3 minV = hasMin ? min.Get<Vector3>() : .(float.MinValue);
							Vector3 maxV = hasMax ? max.Get<Vector3>() : .(float.MaxValue);

							if (ImGui.EditVector3(displayName, ref value, .Zero, 0.1f, 100.0f, minV, maxV))
								material.SetVariable(variable.Name, value);
						case 4:
							material.GetVariable<Vector4>(variable.Name, var value);
							
							Vector4 minV = hasMin ? min.Get<Vector4>() : .(float.MinValue);
							Vector4 maxV = hasMax ? max.Get<Vector4>() : .(float.MaxValue);

							if (ImGui.EditVector4(displayName, ref value, .Zero, 0.1f, 100.0f, minV, maxV))
								material.SetVariable(variable.Name, value);
						}
					}
				}
			}
		}

		private static void LabelColumn(StringView label)
		{
			ImGui.TextUnformatted(label);
			ImGui.NextColumn();
		}

		private static void ShowLightComponentEditor(Entity entity, LightComponent* lightComponent)
		{
			ImGui.Columns(2);
			defer ImGui.Columns(1);

			const String[?] strings = String[]("Directional", "Point", "Spot");

			var light = ref lightComponent.SceneLight;

			String typeName = strings[light.LightType.Underlying];
			
			LabelColumn("Type");

			if (ImGui.BeginCombo("##Type", typeName.CStr()))
			{
				for (int i = 0; i < 3; i++)
				{
					bool isSelected = (typeName == strings[i]);

					if (ImGui.Selectable(strings[i], isSelected))
					{
						light.LightType = (.)i;
					}

					if (isSelected)
						ImGui.SetItemDefaultFocus();
				}

				ImGui.EndCombo();
			}
			
			ImGui.NextColumn();
			LabelColumn("Color");

			ColorRGB color = ColorRGB.LinearToSRGB(light.Color);
			if (ImGui.ColorEdit3("##Color", ref color))
				light.Color = ColorRGB.SRgbToLinear(color);

			ImGui.NextColumn();
			LabelColumn("Illuminance");

			float illuminance = light.Illuminance;
			if (ImGui.DragFloat("##Illuminance", &illuminance, 0.1f, 0.0f, float.MaxValue))
				light.Illuminance = illuminance;
		}

		private static void ShowAddComponentButton(Entity entity)
		{
			static char8[128] searchBuffer = .();
			static StringView searchFilter = .();
			
			static float buttonWidth = 100;

			ImGui.NewLine();
			ImGui.Separator();
			ImGui.NewLine();

			void ShowComponentButton<TComponent>(String name) where TComponent : struct, new
			{
				float textWidth = ImGui.CalcTextSize(name.CStr()).x;
				buttonWidth = Math.Max(buttonWidth, textWidth + ImGui.GetStyle().FramePadding.x * 2);

				if (name.Contains(searchFilter, true) && ImGui.Selectable(name))
				{
					if (!entity.HasComponent<TComponent>())
						entity.AddComponent<TComponent>();
				}
			}

			float textWidth = ImGui.CalcTextSize("Add Component...").x;
			buttonWidth = Math.Max(buttonWidth, textWidth + ImGui.GetStyle().FramePadding.x * 2);

			ImGui.PushItemWidth(buttonWidth);

			ImGui.NewLine();
			ImGui.SameLine(ImGui.GetContentRegionMax().x / 2 - buttonWidth / 2);

			if (ImGui.BeginCombo("##add_component_combo", "Add Component...", .NoArrowButton))
			{
				if (ImGui.InputText("##search_component_name", &searchBuffer, (.)searchBuffer.Count))
				{
					searchFilter = .(&searchBuffer);
				}

				ImGui.Separator();

				ShowComponentButton<CameraComponent>("Camera");
				ShowComponentButton<SpriterRendererComponent>("Sprite Renderer");
				ShowComponentButton<LightComponent>("Light");

				ImGui.EndCombo();
			}

			ImGui.PopItemWidth();
		}
	}
}
