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

		private Texture2D _texture ~ _?.ReleaseRef();

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

		public Texture2D Texture
		{
			get => _texture;
			set
			{
				if(_texture == value)
					return;

				_texture?.ReleaseRef();
				_texture = value;
				_texture?.AddRef();
			}
		}

		public this()
		{
		}

		private ImGui.Vec2 oldViewportSize;

		Texture2D _lastTexture;

		public void Show()
		{
			// Hold a reference to the texture until the next frame.
			// This is a workaround for the issue that changing the window size will release the texture
			_lastTexture?.ReleaseRef();
			_lastTexture = _texture;
			_lastTexture.AddRef();

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

			if(_lastTexture != null)
			{
				ImGui.Image(_lastTexture, viewportSize);
			}
			
			ImGui.End();
			
			if(oldViewportSize != viewportSize)
			{
				ViewportSizeChangedEvent.Invoke(this, *(Vector2*)&viewportSize);

				oldViewportSize = viewportSize;
			}
		}
	}
}
