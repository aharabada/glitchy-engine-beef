using System;
using ImGui;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using GlitchyEngine;
using GlitchyEngine.World;
using ImGuizmo;

namespace GlitchyEditor.EditWindows
{
	class SceneViewportWindow : EditorWindow
	{
		public const String s_WindowTitle = "Scene";

		private RenderTarget2D _renderTarget ~ _?.ReleaseRef();

		public Event<EventHandler<Vector2>> ViewportSizeChangedEvent ~ _.Dispose();

		public RenderTarget2D RenderTarget
		{
			get => _renderTarget;
			set
			{
				if(_renderTarget == value)
					return;

				SetReference!(_renderTarget, value);
			}
		}

		public this(Editor editor)
		{
			_editor = editor;
		}

		private ImGui.Vec2 oldViewportSize;
		private bool viewPortChanged;

		protected override void InternalShow()
		{
			ImGui.PushStyleVar(.WindowPadding, ImGui.Vec2(1, 1));
			defer ImGui.PopStyleVar();

			if(!ImGui.Begin(s_WindowTitle, &_open, .NoScrollbar | .MenuBar))
			{
				ImGui.End();
				return;
			}

			ShowMenuBar();

			if(ImGui.IsWindowHovered() && Input.IsMouseButtonPressing(.RightButton))
			{
				var currentWindow = ImGui.GetCurrentWindow();
				ImGui.FocusWindow(currentWindow);
			}

			_hasFocus = ImGui.IsWindowFocused();

			var viewportSize = ImGui.GetContentRegionAvail();

			if(_renderTarget != null)
			{
				ImGui.Image(_renderTarget, viewportSize);
			}

			DrawImGuizmo(viewportSize);
			
			ImGui.End();

			if(oldViewportSize != viewportSize)
			{
				ViewportSizeChangedEvent.Invoke(this, (Vector2)viewportSize);
				viewPortChanged = true;
				oldViewportSize = viewportSize;
			}
		}

		private ImGuizmo.OPERATION _gizmoType = .TRANSLATE;

		private ImGuizmo.MODE _gizmoMode = .LOCAL;

		private void ShowMenuBar()
		{
			if(ImGui.BeginMenuBar())
			{
				if (ImGui.RadioButton("Position", _gizmoType.HasFlag(.TRANSLATE)))
				{
					if (Input.IsKeyPressed(Key.Control))
						_gizmoType ^= .TRANSLATE;
					else
						_gizmoType = .TRANSLATE;
				}

				if (ImGui.RadioButton("Rotation", _gizmoType.HasFlag(.ROTATE)))
				{
					if (Input.IsKeyPressed(Key.Control))
						_gizmoType ^= .ROTATE;
					else
						_gizmoType = .ROTATE;
				}
				
				if (ImGui.RadioButton("Scale", _gizmoType.HasFlag(.SCALE)))
				{
					if (Input.IsKeyPressed(Key.Control))
						_gizmoType ^= .SCALE;
					else
						_gizmoType = .SCALE;
				}

				if (ImGui.RadioButton("All", _gizmoType == .TRANSLATE | .ROTATE | .SCALE))
					_gizmoType = .TRANSLATE | .ROTATE | .SCALE;

				// If we scale, the mode must be local otherwise we could skew the matrix.
				if (_gizmoType.HasFlag(.SCALE))
					_gizmoMode = .LOCAL;

				if (ImGui.MenuItem(_gizmoMode == .WORLD ? "Global" : "Local", null, true, !_gizmoType.HasFlag(.SCALE)))
				{
					if (_gizmoMode == .WORLD)
						_gizmoMode = .LOCAL;
					else
						_gizmoMode = .WORLD;
				}

				ImGui.EndMenuBar();
			}
		}

		private void DrawImGuizmo(ImGui.Vec2 viewportSize)
		{
			ImGuizmo.SetOrthographic(false);
			ImGuizmo.SetDrawlist();

			var topLeft = ImGui.GetWindowPos();
			var cntMin = ImGui.GetWindowContentRegionMin();

			topLeft.x += cntMin.x;
			topLeft.y += cntMin.y;
			ImGuizmo.SetRect(topLeft.x, topLeft.y, viewportSize.x, viewportSize.y);

			var cameraTransformCmp = _editor.CurrentScene.ActiveCamera.GetComponent<TransformComponent>();
			var view = cameraTransformCmp.WorldTransform.Invert();

			var cameraCmp = _editor.CurrentCamera.GetComponent<CameraComponent>();
			var projection = cameraCmp.Camera.Projection;

			if(_editor.EntityHierarchyWindow.SelectedEntities.Count == 0)
				return;

			var entity = _editor.EntityHierarchyWindow.SelectedEntities.Back;

			var transformCmp = entity.GetComponent<TransformComponent>();

			var worldTransform = transformCmp.WorldTransform;

			Matrix parentView = .Identity;
			if (transformCmp.Parent != .InvalidEntity)
			{
				var parentTransformCmp = Entity(transformCmp.Parent, entity.Scene).GetComponent<TransformComponent>();
				parentView = parentTransformCmp.WorldTransform.Invert();
			}

			if (ImGuizmo.Manipulate((.)&view, (.)&projection, _gizmoType, _gizmoMode, (.)&worldTransform))
			{
				// TODO: Fix when parent is scaled
				// Seems to work fine for parent rotation and translation but scaled parent ruins everything
				// (probably because scaling a rotated matrix results in a skewed matrix, but unity can do it, so should we)
				transformCmp.LocalTransform = parentView * worldTransform;
			}
		}
	}
}
