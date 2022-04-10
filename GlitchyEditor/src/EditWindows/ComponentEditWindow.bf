using ImGui;
using GlitchyEngine.World;
using System;
using GlitchyEngine.Math;
using System.Collections;

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
			if(!ImGui.Begin(s_WindowTitle, &_open, .None))
			{
				ImGui.End();
				return;
			}

			if(_entityHierarchyWindow.SelectedEntities.Count == 1)
			{
				Entity entity = _entityHierarchyWindow.SelectedEntities.Front;

				ShowComponents(entity);
			}

			ImGui.End();
		}

		private void ShowComponents(Entity entity)
		{
			ShowNameComponentEditor(entity);

			ShowComponentEditor<TransformComponent>("Transform", entity, => ShowTransformComponentEditor);
			ShowComponentEditor<CameraComponent>("Camera", entity, => ShowCameraComponentEditor, => ShowComponentContextMenu<CameraComponent>);
			ShowComponentEditor<SpriterRendererComponent>("Sprite Renderer", entity, => ShowSpriteRendererComponentEditor, => ShowComponentContextMenu<SpriterRendererComponent>);

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

			bool nodeOpen = ImGui.TreeNodeEx(header.CStr(), .DefaultOpen | .AllowItemOverlap | .Framed);

			if (showComponentContextMenu != null)
			{
				ImGui.SameLine(ImGui.GetWindowContentRegionMax().x - ImGui.CalcTextSize("...").x);

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
			Vector3 position = transform.Position;
			if (ImGui.EditVector3("Position", ref position))
				transform.Position = position;

			Vector3 rotationEuler = MathHelper.ToDegrees(transform.EditorRotationEuler);
			if (ImGui.EditVector3("Rotation", ref rotationEuler))
				transform.EditorRotationEuler = MathHelper.ToRadians(rotationEuler);
			
			Vector3 scale = transform.Scale;
			if (ImGui.EditVector3("Scale", ref scale, .One))
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
			ImGui.ColorEdit4("Color", ref spriteRendererComponent.Color);
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

				ImGui.EndCombo();
			}

			ImGui.PopItemWidth();
		}
	}
}
