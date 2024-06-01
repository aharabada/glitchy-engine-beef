using System;
using GlitchyEngine.Events;
using GlitchyEngine.ImGui;
using GlitchyEngine.Renderer;
using GlitchyEngine.Debug;
using GlitchyEngine.Content;
using GlitchyEngine.Scripting;
using System.Collections;
using System.Threading;

namespace GlitchyEngine
{
	public abstract class Application
	{
		static Application s_Instance = null;

		private Window _window;
		private RendererAPI _rendererApi;

		private bool _running = true;
		private bool _isMinimized = false;

		private LayerStack _layerStack;

#if IMGUI
		private ImGuiLayer _imGuiLayer;
#endif

		private GameTime _gameTime;
		
		private IContentManager _contentManager;

		private append List<delegate bool()> _jobQueue = .() ~ ClearAndDeleteItems!(_);
		private append Monitor _jobQueueMutex = .();

		public bool IsRunning => _running;
		public Window Window => _window;

		public IContentManager ContentManager => _contentManager;

		public bool IsMinimized => _isMinimized;

		public GameTime GameTime => _gameTime;

		[Inline, Obsolete("Use Application.Instance instead.", false), NoShow]
		public static Application Get() => s_Instance;

		public static Application Instance => s_Instance;

		public Settings Settings {get; private set;} = new .() ~ delete _;

		public this()
		{
			Profiler.ProfileFunction!();

			Log.EngineLogger.Assert(s_Instance == null, "Tried to create a second application.");
			s_Instance = this;

			_layerStack = new LayerStack();
			_gameTime = new GameTime(true);

			WindowDescription windowDesc = .Default;
			windowDesc.Icon = "Resources/Textures/GlitchyEngineIcon.ico";

			_window = new Window(windowDesc);
			_window.EventCallback = new => OnEvent;

			Input.Init();
			
			_contentManager = InitContentManager();

			// TODO: RenderAPI in RenderCommand initialisieren?
			_rendererApi = new RendererAPI();
			_rendererApi.Context = _window.Context;

			SamplerStateManager.Init();

			// TODO: Rendercommmand in Renderer initialisieren?
			RenderCommand.RendererAPI = _rendererApi;

			Renderer.Init();
			ScriptEngine.Init();

#if IMGUI
			_imGuiLayer = new ImGuiLayer();
			PushOverlay(_imGuiLayer);
#endif

			GlitchyEngine.Settings.Load();
			Settings.Apply();
		}

		/// Initializes the content manager.
		protected abstract IContentManager InitContentManager();
		//{
			// TODO: init default content manager?
			//_contentManager = new ContentManager("./content");
		//}

		public ~this()
		{
			Profiler.ProfileFunction!();

			SamplerStateManager.Uninit();

			Renderer.Deinit();

			delete _contentManager;
			
			delete _layerStack;

			delete _rendererApi;
			delete _window;
			
			delete _gameTime;

			ScriptEngine.Shutdown();
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

				RunJobs();

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

		/// Executes the given Job on the main thread. Takes ownership of the delegate.
		public void InvokeOnMainThread(delegate bool() ownJob)
		{
			using (_jobQueueMutex.Enter())
			{
				_jobQueue.Add(ownJob);
			}
		}

		private void RunJobs()
		{
			Debug.Profiler.ProfileFunction!();

			using (_jobQueueMutex.Enter())
			{
				for (let job in _jobQueue)
				{
					if (job())
					{
						@job.RemoveFast();
						delete job;
					}
				}

				//ClearAndDeleteItems!(_jobQueue);
			}
		}
	}
}
