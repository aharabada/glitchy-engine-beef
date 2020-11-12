using System;
using GlitchyEngine.Events;
using GlitchyEngine.Platform.Windows;
using GlitchyEngine.Platform.DX11;

namespace GlitchyEngine
{
	public class Application
	{
		static Application s_Instance = null;

		private Window _window ~ delete _;
		private bool _running = true;

		private LayerStack _layerStack = new LayerStack() ~ delete _;

		private GameTime _gameTime = new GameTime(true) ~ delete _;

		public bool IsRunning => _running;
		public Window Window => _window;

		[Inline]
		public static Application Get => s_Instance;

		public this()
		{
			Runtime.Assert(s_Instance == null, "Tried to create a second application.");
			s_Instance = this;

			_window = GlitchyEngine.Window.CreateWindow(WindowDescription());
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
				DirectX.ImmediateContext.ClearRenderTargetView(DirectX.BackBufferTarget, .(1, 0, 1));

				_gameTime.Tick();
			
				for(Layer layer in _layerStack)
					layer.Update(_gameTime);

				_window.Update();

				DirectX.Present();
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
