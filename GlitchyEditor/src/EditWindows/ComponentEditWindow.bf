using ImGui;
using GlitchyEngine.World;
using System;
using GlitchyEngine.Math;

namespace GlitchyEditor.EditWindows
{
	class ComponentEditWindow : EditorWindow
	{
		public const String s_WindowTitle = "Components";

		public Editor Editor => _editor;
		
		public this(Editor editor)
		{
			_editor = editor;
		}

		protected override void InternalShow()
		{
			if(!ImGui.Begin(s_WindowTitle, &_open, .None))
			{
				ImGui.End();
				return;
			}

			if(_editor.SelectedEntities.Count == 1)
			{
				Entity entity = _editor.SelectedEntities.Front;

				ShowComponents(entity);
			}

			ImGui.End();
		}

		private void ShowComponents(Entity entity)
		{
			NameComponentEditor.Show(_editor.World, entity);
			TransformComponentEditor.Show(_editor.World, entity);		
		}
	}

	static class NameComponentEditor
	{
		public static void Show(EcsWorld world, Entity entity)
		{
			char8[128] nameBuffer = default;

			DebugNameComponent* component = world.GetComponent<DebugNameComponent>(entity);

			String name = null;

			if(component != null)
			{
				name = component.DebugName;
			}
			else
			{
				name = scope:: $"Entity {entity.[Friend]Index}";
			}

			// Copy name to buffer
			Internal.MemCpy(&nameBuffer, name.Ptr, Math.Min(nameBuffer.Count, name.Length));

			if(ImGui.InputText("Name", &nameBuffer, nameBuffer.Count))
			{
				if(component == null)
				{
					component = world.AssignComponent<DebugNameComponent>(entity);
				}

				component.DebugName.Clear();
				component.DebugName.Append(&nameBuffer);
			}
		}
	}

	static class TransformComponentEditor
	{
		public static void Show(EcsWorld world, Entity entity)
		{
			TransformComponent* component = world.GetComponent<TransformComponent>(entity);

			if(component == null)
				return;

			if(ImGui.TreeNodeEx("Transform", .DefaultOpen))
			{
				Vector3 position = component.Position;
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

				ImGui.TreePop();
			}
		}
	}
}
