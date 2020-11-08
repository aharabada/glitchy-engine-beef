using GlitchyEngine.Platform.Windows;
using GlitchyEngine.Events;

namespace GlitchyEngine
{
	public class Application
	{
		private Window _window ~ delete _;
		private bool _running = true;

		public bool IsRunning => _running;

		public this()
		{
			// Todo: make Platform independent
			_window = new WindowsWindow(WindowDescription());
			_window.EventCallback = new => OnEvent;
		}

		public void Run()
		{
			while(_running)
			{
				_window.Update();
			}
		}

		public void OnEvent(Event e)
		{
			EventDispatcher dispatcher = scope .(e);
			dispatcher.Dispatch<WindowCloseEvent>(scope => OnWindowClose);

			Log.EngineLogger.Trace("{}", e);
		}
		
		public bool OnWindowClose(WindowCloseEvent e)
		{
			_running = false;
			return true;
		}
	}
}
