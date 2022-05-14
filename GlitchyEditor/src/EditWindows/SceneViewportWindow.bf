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

			if(!ImGui.Begin(s_WindowTitle, &_open, .NoScrollbar))
			{
				ImGui.End();
				return;
			}

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

		private void DrawImGuizmo(ImGui.Vec2 viewportSize)
		{
			ImGuizmo.SetDrawlist();

			var topLeft = ImGui.GetWindowPos();
			var cntMin = ImGui.GetWindowContentRegionMin();

			topLeft.x += cntMin.x;
			topLeft.y += cntMin.y;
			ImGuizmo.SetRect(topLeft.x, topLeft.y, viewportSize.x, viewportSize.y);

			var cameraTransformCmp = _editor.CurrentCamera.GetComponent<TransformComponent>();
			var view = cameraTransformCmp.WorldTransform.Invert();

			var cameraCmp = _editor.CurrentCamera.GetComponent<CameraComponent>();
			var projection = cameraCmp.Camera.Projection;

			Matrix mat = .Identity;
			ImGuizmo.DrawGrid((.)&view, (.)&projection, (.)&mat, 10);

			if(_editor.EntityHierarchyWindow.SelectedEntities.Count > 0)
			{
				var entity = _editor.EntityHierarchyWindow.SelectedEntities.Front;

				var transformCmp = entity.GetComponent<TransformComponent>();

				var transform = transformCmp.LocalTransform;

				ImGuizmo.SetRect(topLeft.x, topLeft.y, viewportSize.x, viewportSize.y);

				ImGuizmo.Manipulate((.)&view, (.)&projection, .TRANSLATE, .LOCAL, (.)&transform);

				transformCmp.LocalTransform = transform;
			}
		}
	}
}
