using System;
using ImGui;
namespace GlitchyEditor.EditWindows
{
	abstract class EditorWindow
	{
		protected Editor _editor;
		
		protected bool _open = true;
		protected bool _hasFocus;

		public bool Open
		{
			get => _open;
			set => _open = value;
		}

		public bool HasFocus
		{
			get => _hasFocus;
		}

		public void Show()
		{
			if(!_open)
				return;
			
			InternalShow();
		}

		protected abstract void InternalShow();
	}

	abstract class ClosableWindow
	{
		private static int32 _nextWindowId = 9000;

		private String _windowTitle ~ delete _;
		private String _windowTitleId ~ delete _;
		private int32 _windowId;

		protected Editor _editor;

		public StringView WindowTitle
		{
			get => _windowTitle;
			set
			{
				String.NewOrSet!(_windowTitle, value);
				String.NewOrSet!(_windowTitleId, value);
				_windowTitleId.AppendF($"##{_windowId}");
			}
		}

		public StringView WindowTitleWithId => _windowTitleId;

		public this(Editor editor, StringView windowTitle = "Window")
		{
			_windowId = ++_nextWindowId;
			_editor = editor;
			WindowTitle = windowTitle;

			_editor.AddWindow(this);
		}

		public void Show()
		{
			bool open = true;

			if(ImGui.Begin(_windowTitleId, &open, .None))
			{
				InternalShow();
			}

			ImGui.End();

			if (!open)
			{
				_editor.RemoveWindow(this);
			}
		}

		protected abstract void InternalShow();
	}
}