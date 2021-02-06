using System;
using GlitchyEngine.Events;
using GlitchyEngine.ImGui;
using GlitchyEngine.Renderer;

namespace GlitchyEngine
{
	public class Application
	{
		static Application s_Instance = null;

		private Window _window ~ delete _;
		private RendererAPI _rendererApi ~ delete _;
		private bool _running = true;

		private LayerStack _layerStack = new LayerStack() ~ delete _;

		private ImGuiLayer _imGuiLayer;

		private GameTime _gameTime = new GameTime(true) ~ delete _;

		public bool IsRunning => _running;
		public Window Window => _window;

		[Inline]
		public static Application Get() => s_Instance;

		public this()
		{
			Log.EngineLogger.Assert(s_Instance == null, "Tried to create a second application.");
			s_Instance = this;

			_window = new Window(.Default);
			_window.EventCallback = new => OnEvent;

			_rendererApi = new RendererAPI();
			_rendererApi.Context = _window.Context;

			RenderCommand.RendererAPI = _rendererApi;
			
			Renderer.Init(_window.Context);

			_imGuiLayer = new ImGuiLayer();
			PushOverlay(_imGuiLayer);
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
				_gameTime.NewFrame();

				Input.NewFrame();

				for(Layer layer in _layerStack)
					layer.Update(_gameTime);
				
				_window.Update();

				_imGuiLayer.ImGuiRender();

				_window.Context.SwapChain.Present();
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
