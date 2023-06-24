using System;
using ImGui;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using GlitchyEngine;
using GlitchyEngine.World;
using ImGuizmo;
using GlitchyEngine.Events;

namespace GlitchyEditor.EditWindows
{
	class GameViewportWindow : EditorWindow
	{
		public const String s_WindowTitle = "Game";

		private ImGui.Vec2 _oldViewportSize = .(100, 100);
		private bool _viewPortChanged;

		private bool _visible;

		private RenderTargetGroup _renderTarget ~ _?.ReleaseRef();

		public float2 ViewportSize => (float2)_oldViewportSize;
		// Occurs when the viewport is resized.
		public Event<EventHandler<float2>> ViewportSizeChanged ~ _.Dispose();
		// Occurs when an entity was clicked.
		public Event<EventHandler<uint32>> EntityClicked ~ _.Dispose();

		/// The render target that is shown in the viewport window.
		public RenderTargetGroup RenderTarget
		{
			get => _renderTarget;
			set
			{
				if(_renderTarget == value)
					return;

				SetReference!(_renderTarget, value);
			}
		}

		public bool Visible => _visible;

		public this(Editor editor)
		{
			_editor = editor;
		}

		protected override void InternalShow()
		{
			ImGui.PushStyleVar(.WindowPadding, ImGui.Vec2(1, 1));
			defer ImGui.PopStyleVar();

			if(!ImGui.Begin(s_WindowTitle, &_open, .NoScrollbar | .MenuBar))
			{
				ImGui.End();

				_visible = false;
				return;
			}

			_visible = true;

			let viewportSize = ImGui.GetContentRegionAvail();

			if(ImGui.IsWindowHovered() && Input.IsMouseButtonPressing(.RightButton))
			{
				let currentWindow = ImGui.GetCurrentWindow();
				ImGui.FocusWindow(currentWindow);
			}

			_hasFocus = ImGui.IsWindowFocused();
			
			if(_renderTarget != null)
			{
				ImGui.Image(_renderTarget.GetViewBinding(0), viewportSize);
			}

			ImGui.End();

			if(_oldViewportSize != viewportSize)
			{
				ViewportSizeChanged.Invoke(this, (float2)viewportSize);
				_viewPortChanged = true;
				_oldViewportSize = viewportSize;
			}
		}

		/// Provides the ImGui Drop target and handles dropped payload.
		private void HandleDropTarget()
		{
			if (ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = ImGui.AcceptDragDropPayload("CONTENT_BROWSER_ITEM");

				if (payload != null)
				{
					StringView path = .((char8*)payload.Data, (int)payload.DataSize);
					_editor.RequestOpenScene(this, path);
				}

				ImGui.EndDragDropTarget();
			}
		}
	}
}
