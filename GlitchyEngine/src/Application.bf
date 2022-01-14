using System;
using GlitchyEngine.Events;
using GlitchyEngine.ImGui;
using GlitchyEngine.Renderer;
using GlitchyEngine.Debug;

namespace GlitchyEngine
{
	public class Application
	{
		static Application s_Instance = null;

		private Window _window ~ delete _;
		private RendererAPI _rendererApi ~ delete _;
		private EffectLibrary _effectLibrary ~ delete _;

		private bool _running = true;
		private bool _isMinimized = false;

		private LayerStack _layerStack = new LayerStack();

		private ImGuiLayer _imGuiLayer;

		private GameTime _gameTime = new GameTime(true);

		public bool IsRunning => _running;
		public Window Window => _window;

		public EffectLibrary EffectLibrary => _effectLibrary;

		public bool IsMinimized => _isMinimized;

		[Inline]
		public static Application Get() => s_Instance;

		public this()
		{
			Profiler.ProfileFunction!();

			Log.EngineLogger.Assert(s_Instance == null, "Tried to create a second application.");
			s_Instance = this;

			_window = new Window(.Default);
			_window.EventCallback = new => OnEvent;

			_rendererApi = new RendererAPI();
			_rendererApi.Context = _window.Context;

			SamplerStateManager.Init();

			RenderCommand.RendererAPI = _rendererApi;

			_effectLibrary = new EffectLibrary();

			Renderer.Init(_window.Context, _effectLibrary);

			_imGuiLayer = new ImGuiLayer();
			PushOverlay(_imGuiLayer);
		}

		public ~this()
		{
			Profiler.ProfileFunction!();

			delete _layerStack;
			SamplerStateManager.Uninit();
			Renderer.Deinit();
			delete _gameTime;
		}

		public void OnEvent(Event e)
		{
			Debug.Profiler.ProfileFunction!();

			if(!_running)
				return;

			EventDispatcher dispatcher = EventDispatcher(e);
			dispatcher.Dispatch<WindowCloseEvent>(scope => OnWindowClose);

			dispatcher.Dispatch<WindowResizeEvent>(scope => OnWindowResize);

			for(Layer layer in _layerStack)
			{
				layer.OnEvent(e);
				if(e.Handled)
					break;
			}
		}
		
#if GE_APP_SINGLESTEP
		bool allowFrame = false;
		bool disableSingleFrame = false;
#else
		const bool allowFrame = true;
#endif

		public void Run()
		{
			Debug.Profiler.ProfileFunction!();

			while(_running)
			{
				Debug.Profiler.ProfileScope!("Loop");

				if(allowFrame)
				{
					_gameTime.NewFrame();
				}

				Input.NewFrame();
				
#if GE_APP_SINGLESTEP
				allowFrame = disableSingleFrame || Input.IsKeyPressing(Key.F10);

				if(Input.IsKeyPressing(Key.F11))
				{
					disableSingleFrame = !disableSingleFrame;
				}
#endif

				if(allowFrame && !_isMinimized)
				{
					Debug.Profiler.ProfileScope!("Update Layers");

					for(Layer layer in _layerStack)
						layer.Update(_gameTime);
				}
				
				_window.Update();
				
				if(allowFrame)
				{
					_imGuiLayer.ImGuiRender();
	
					_window.Context.SwapChain.Present();
				}
			}
		}

		public void PushLayer(Layer ownLayer)
		{
			Profiler.ProfileFunction!();

			_layerStack.PushLayer(ownLayer);
			ownLayer.OnAttach();
		}

		public void PushOverlay(Layer ownOverlay)
		{
			Profiler.ProfileFunction!();

			_layerStack.PushOverlay(ownOverlay);
			ownOverlay.OnAttach();
		}

		public bool OnWindowClose(WindowCloseEvent e)
		{
			_running = false;
			return true;
		}

		public bool OnWindowResize(WindowResizeEvent e)
		{
			if(e.Width == 0 || e.Height == 0)
			{
				_isMinimized = true;
				return false;
			}

			_isMinimized = false;

			return false;
		}
	}
}
