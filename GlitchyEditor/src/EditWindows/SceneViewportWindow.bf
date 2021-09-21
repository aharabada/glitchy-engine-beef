using System;
using ImGui;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using GlitchyEngine;

namespace GlitchyEditor.EditWindows
{
	class SceneViewportWindow
	{
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

		public this()
		{
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
			
			if(oldViewportSize != viewportSize)
			{
				ViewportSizeChangedEvent.Invoke(this, *(Vector2*)&oldViewportSize);
				viewPortChanged = true;
				oldViewportSize = viewportSize;
			}

			if(_renderTarget != null)
			{
				ImGui.Image(_renderTarget, viewportSize);
			}
			
			ImGui.End();
		}
	}
}
