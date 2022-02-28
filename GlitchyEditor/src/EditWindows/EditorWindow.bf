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
}