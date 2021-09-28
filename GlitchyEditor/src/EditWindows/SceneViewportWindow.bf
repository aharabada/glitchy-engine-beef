using System;
using ImGui;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using GlitchyEngine;
using GlitchyEngine.World;
using ImGuizmo;

namespace GlitchyEditor.EditWindows
{
	class SceneViewportWindow
	{
		private Editor _editor;
		public Camera _camera;

		public const String s_WindowTitle = "Scene";

		private bool _open = true;

		private RenderTarget2D _renderTarget ~ _?.ReleaseRef();

		private bool _hasFocus;

		public Event<EventHandler<Vector2>> ViewportSizeChangedEvent ~ _.Dispose();

		public bool Open
		{
			get => _open;
			set => _open = value;
		}

		public bool HasFocus
		{
			get => _hasFocus;
		}

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

		public void Show()
		{
			if(!_open)
				return;
			
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

			if(_editor.SelectedEntities.Count > 0)
			{
				ImGuizmo.SetDrawlist();

				var entity = _editor.SelectedEntities.Back;

				var transformCmp = _editor.World.GetComponent<TransformComponent>(entity);

				var transform = transformCmp.LocalTransform;

				var view = _camera.View;
				var projection = _camera.Projection;

				var v = ImGui.GetWindowPos();
				var cntMin = ImGui.GetWindowContentRegionMin();

				v.x += cntMin.x;
				v.y += cntMin.y;
				
				ImGuizmo.SetRect(v.x, v.y, viewportSize.x, viewportSize.y);

				Color c = .(0,0,0,255);
				
				//ImGuizmo.DrawCubes((.)&view, (.)&projection, (.)&transform, 1);
				ImGuizmo.Manipulate((.)&view, (.)&projection, .TRANSLATE, .LOCAL, (.)&transform);

				Matrix mat = .Identity;

				ImGuizmo.DrawGrid((.)&view, (.)&projection, (.)&mat, 10);

				transformCmp.LocalTransform = transform;
				//ImGuizmo.ViewManipulate((.)&view, , .TRANSLATE, .LOCAL, (.)&transform);
			}
			
			ImGui.End();

			if(oldViewportSize != viewportSize)
			{
				ViewportSizeChangedEvent.Invoke(this, *(Vector2*)&oldViewportSize);
				viewPortChanged = true;
				oldViewportSize = viewportSize;
			}
		}
	}
}
