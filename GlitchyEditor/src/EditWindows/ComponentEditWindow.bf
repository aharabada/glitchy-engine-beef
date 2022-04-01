using ImGui;
using GlitchyEngine.World;
using System;
using GlitchyEngine.Math;

namespace GlitchyEditor.EditWindows
{
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

		private static void ShowTransformComponentEditor(Entity entity)
		{
			if (!entity.HasComponent<SimpleTransformComponent>())
				return;

			var transform = entity.GetComponent<SimpleTransformComponent>();

			if(ImGui.TreeNodeEx("Transform", .DefaultOpen))
			{
				bool ShowValue(String text, ref float value, String id)
				{
					ImGui.Text(text);
					ImGui.SameLine();
					ImGui.PushID(id);
					bool valueChanged = ImGui.DragFloat(String.Empty, &value, 0.1f);
					ImGui.PopID();

					return valueChanged;
				}

				bool ShowTableRow(String name, ref Vector3 value)
				{
					bool changed = false;

					ImGui.TableNextColumn();

					ImGui.Text(name);
					ImGui.TableNextColumn();
					changed |= ShowValue("X: ", ref value.X, scope $"{name}X");
					ImGui.TableNextColumn();
					changed |= ShowValue("Y: ", ref value.Y, scope $"{name}Y");
					ImGui.TableNextColumn();
					changed |= ShowValue("Z: ", ref value.Z, scope $"{name}Z");
					
					ImGui.TableNextRow();

					return changed;
				}

				Matrix.Decompose(transform.Transform, var position, var rotation, var scale);

				ImGui.BeginTable("posRotScaleTable", 4);

				if (ShowTableRow("Position", ref position))
				{
					transform.Transform.Translation = position;
				}

				var oldScale = scale;
				if (ShowTableRow("Scale", ref scale))
				{
					Vector3 v = 1.0f / oldScale * scale;

					transform.Transform.Scale = (Vector3)transform.Transform.Scale * v;
				}


				ImGui.EndTable();

				/*
				Vector3 position = transform.Position;
				bool positionChanged = false;
				
				Vector3 rotationEuler = MathHelper.ToDegrees(component.RotationEuler);
				bool rotationChanged = false;
				
				Vector3 scale = component.Scale;
				bool scaleChanged = false;

				void ShowValue(String text, ref float value, ref bool valueChanged, String id)
				{
					ImGui.Text(text);
					ImGui.SameLine();
					ImGui.PushID(id);
					valueChanged |= ImGui.DragFloat(String.Empty, &value, 0.1f);
					ImGui.PopID();
				}

				void ShowTableRow(String name, ref Vector3 value, ref bool valueChanged)
				{
					ImGui.TableNextColumn();

					ImGui.Text(name);
					ImGui.TableNextColumn();
					ShowValue("X: ", ref value.X, ref valueChanged, scope $"{name}X");
					ImGui.TableNextColumn();
					ShowValue("Y: ", ref value.Y, ref valueChanged, scope $"{name}Y");
					ImGui.TableNextColumn();
					ShowValue("Z: ", ref value.Z, ref valueChanged, scope $"{name}Z");
					
					ImGui.TableNextRow();
				}
				
				ImGui.BeginTable("posRotScaleTable", 4);

				ShowTableRow("Position", ref position, ref positionChanged);
				ShowTableRow("Rotation", ref rotationEuler, ref rotationChanged);
				ShowTableRow("Scale", ref scale, ref scaleChanged);

				ImGui.EndTable();

				if(positionChanged)
					component.Position = position;

				if(rotationChanged)
					component.RotationEuler = MathHelper.ToRadians(rotationEuler);

				if(scaleChanged)
					component.Scale = scale;

				*/
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
