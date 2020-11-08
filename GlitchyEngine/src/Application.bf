using GlitchyEngine.Platform.Windows;

namespace GlitchyEngine
{
	public class Application
	{
		private Window _window ~ delete _;
		private bool _running;

		public bool IsRunning => _running;

		public this()
		{
			// Todo: make Platform independent
			_window = new WindowsWindow(WindowDescription());
		}

		public void Run()
		{
			_running = true;

			while(_running)
			{
				_window.Update();
			}
		}
	}
}
