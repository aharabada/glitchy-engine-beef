using ImGui;
using GlitchyEngine.World;
using System;
using GlitchyEngine.Math;

namespace GlitchyEditor.EditWindows
{
	using internal GlitchyEngine.World.TransformComponent;

	class ComponentEditWindow : EditorWindow
	{
		public const String s_WindowTitle = "Components";

		private EntityHierarchyWindow _entityHierarchyWindow;

		public this(EntityHierarchyWindow entityHierarchyWindow)
		{
			_entityHierarchyWindow = entityHierarchyWindow;
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
			ShowTransformComponentEditor(entity);
			ShowCameraComponentEditor(entity);
			ShowSpriteRendererComponentEditor(entity);
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

		private static bool Vector3Control(StringView label, ref Vector3 value, Vector3 resetValues = .Zero, float dragSpeed = 0.1f, float columnWidth = 100f)
		{
			bool changed = false;

			ImGui.PushID(label);
			defer ImGui.PopID();

			ImGui.Columns(2);
			defer ImGui.Columns(1);
			ImGui.SetColumnWidth(0, columnWidth);

			ImGui.TextUnformatted(label);

			ImGui.NextColumn();

			ImGui.PushMultiItemsWidths(3, ImGui.CalcItemWidth());
			ImGui.PushStyleVar(.ItemSpacing, ImGui.Vec2.Zero);
			defer ImGui.PopStyleVar();

			float lineHeight = ImGui.GetFont().FontSize + ImGui.GetStyle().FramePadding.y * 2.0f;
			ImGui.Vec2 buttonSize = .(lineHeight + 3.0f, lineHeight);

			ImGui.PushStyleColor(.Button, ImGui.Color(230, 25, 45).Value);
			ImGui.PushStyleColor(.ButtonHovered, ImGui.Color(150, 25, 45).Value);
			ImGui.PushStyleColor(.ButtonActive, ImGui.Color(230, 120, 130).Value);

			if (ImGui.Button("X", buttonSize))
			{
				value.X = resetValues.X;
				changed = true;
			}

			ImGui.SameLine();

			if (ImGui.DragFloat("##X", &value.X, dragSpeed))
				changed = true;

			ImGui.PopItemWidth();
			ImGui.SameLine();

			ImGui.PopStyleColor(3);
			ImGui.PushStyleColor(.Button, ImGui.Color(50, 190, 15).Value);
			ImGui.PushStyleColor(.ButtonHovered, ImGui.Color(50, 120, 15).Value);
			ImGui.PushStyleColor(.ButtonActive, ImGui.Color(116, 190, 99).Value);

			if (ImGui.Button("Y", buttonSize))
			{
				value.Y = resetValues.Y;
				changed = true;
			}
			
			ImGui.SameLine();

			if (ImGui.DragFloat("##Y", &value.Y, dragSpeed))
				changed = true;
			
			ImGui.PopItemWidth();
			ImGui.SameLine();
			
			ImGui.PopStyleColor(3);
			ImGui.PushStyleColor(.Button, ImGui.Color(55, 55, 230).Value);
			ImGui.PushStyleColor(.ButtonHovered, ImGui.Color(55, 55, 150).Value);
			ImGui.PushStyleColor(.ButtonActive, ImGui.Color(90, 90, 230).Value);

			if (ImGui.Button("Z", buttonSize))
			{
				value.Z = resetValues.Z;
				changed = true;
			}
			
			ImGui.SameLine();

			if (ImGui.DragFloat("##Z", &value.Z, dragSpeed))
				changed = true;
			
			ImGui.PopItemWidth();

			ImGui.PopStyleColor(3);

			return changed;
		}

		private static void ShowTransformComponentEditor(Entity entity)
		{
			if (!entity.HasComponent<TransformComponent>())
				return;

			var transform = entity.GetComponent<TransformComponent>();

			if(ImGui.TreeNodeEx("Transform", .DefaultOpen))
			{
				Vector3 position = transform.Position;
				if (Vector3Control("Position", ref position))
					transform.Position = position;

				Vector3 rotationEuler = MathHelper.ToDegrees(transform.EditorRotationEuler);
				if (Vector3Control("Rotation", ref rotationEuler))
					transform.EditorRotationEuler = MathHelper.ToRadians(rotationEuler);
				
				Vector3 scale = transform.Scale;
				if (Vector3Control("Scale", ref scale, .One))
					transform.Scale = scale;

				ImGui.TreePop();
			}
		}
		
		static String[] strings = new String[]("Orthographic", "Perspective", "Perspective (Infinite)") ~ delete _;

		private static void ShowCameraComponentEditor(Entity entity)
		{
			if (!entity.HasComponent<CameraComponent>())
				return;

			if(ImGui.TreeNodeEx("Camera", .DefaultOpen))
			{
				var cameraComponent = entity.GetComponent<CameraComponent>();

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

				ImGui.TreePop();
			}
		}

		private static void ShowSpriteRendererComponentEditor(Entity entity)
		{
			if (!entity.HasComponent<SpriterRendererComponent>())
				return;
			
			var spriterRendererComponent = entity.GetComponent<SpriterRendererComponent>();

			if(ImGui.TreeNodeEx("Sprite Renderer", .DefaultOpen))
			{
				ImGui.ColorEdit4("Color", ref spriterRendererComponent.Color);

				ImGui.TreePop();
			}
		}
	}
}
