using GlitchyEngine.Events;
using GlitchyEngine.Platform.Windows;

namespace GlitchyEngine
{
	public class Application
	{
		private Window _window ~ delete _;
		private bool _running = true;

		private LayerStack _layerStack = new LayerStack() ~ delete _;

		public bool IsRunning => _running;

		public this()
		{
			// Todo: make Platform independent
			_window = new WindowsWindow(WindowDescription());
			_window.EventCallback = new => OnEvent;
		}

		public void OnEvent(Event e)
		{
			EventDispatcher dispatcher = scope .(e);
			dispatcher.Dispatch<WindowCloseEvent>(scope => OnWindowClose);

			for(Layer layer in _layerStack)
			{
				layer.OnEvent(e);
				if(e.Handled)
					break;
			}
		}

		public void Run()
		{
			while(_running)
			{
				for(Layer layer in _layerStack)
					layer.Update();

				_window.Update();
			}
		}

		public void PushLayer(Layer ownLayer) => _layerStack.PushLayer(ownLayer);

		public void PushOverlay(Layer ownOverlay) => _layerStack.PushOverlay(ownOverlay);

		public bool OnWindowClose(WindowCloseEvent e)
		{
			_running = false;
			return true;
		}
	}
}
