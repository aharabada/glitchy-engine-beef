using System;
using GlitchyEngine.Events;
using GlitchyEngine.ImGui;
using GlitchyEngine.Renderer;
using GlitchyEngine.Debug;
using GlitchyEngine.Content;

namespace GlitchyEngine
{
	public class Application
	{
		static Application s_Instance = null;

		private Window _window;
		private RendererAPI _rendererApi;
		private EffectLibrary _effectLibrary;

		private bool _running = true;
		private bool _isMinimized = false;

		private LayerStack _layerStack;

#if IMGUI
		private ImGuiLayer _imGuiLayer;
#endif

		private GameTime _gameTime;
		
		private IContentManager _contentManager;

		public bool IsRunning => _running;
		public Window Window => _window;

		public EffectLibrary EffectLibrary => _effectLibrary;

		public IContentManager ContentManager => _contentManager;

		public bool IsMinimized => _isMinimized;

		[Inline]
		public static Application Get() => s_Instance;

		public Settings Settings {get; private set;} = new .() ~ delete _;

		public this()
		{
			Profiler.ProfileFunction!();

			Log.EngineLogger.Assert(s_Instance == null, "Tried to create a second application.");
			s_Instance = this;

			_layerStack = new LayerStack();
			_gameTime = new GameTime(true);

			_window = new Window(.Default);
			_window.EventCallback = new => OnEvent;

			Input.Init();

			_rendererApi = new RendererAPI();
			_rendererApi.Context = _window.Context;

			_contentManager = new ContentManager("./content");

			SamplerStateManager.Init();

			RenderCommand.RendererAPI = _rendererApi;

			_effectLibrary = new EffectLibrary();

			Renderer.Init(_window.Context, _effectLibrary);

#if IMGUI
			_imGuiLayer = new ImGuiLayer();
			PushOverlay(_imGuiLayer);
#endif

			GlitchyEngine.Settings.Load();
			Settings.Apply();
		}

		public ~this()
		{
			Profiler.ProfileFunction!();

			SamplerStateManager.Uninit();
			Renderer.Deinit();

			delete _effectLibrary;

			delete _contentManager;

			delete _rendererApi;
			delete _window;
			
			delete _gameTime;
			delete _layerStack;
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
#if IMGUI
					_imGuiLayer.ImGuiRender();
#endif
	
					_window.Context.SwapChain.Present();
				}
			}
		}

		/// Closes the applcation.
		public void Close()
		{
			_running = false;
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
