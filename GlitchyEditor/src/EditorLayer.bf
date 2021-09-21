using GlitchyEditor.EditWindows;
using GlitchyEngine;
using GlitchyEngine.Events;
using GlitchyEngine.ImGui;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using GlitchyEngine.World;
using ImGui;
using System;
using GlitchyEngine.Renderer.Text;

namespace GlitchyEditor
{
	class EditorLayer : Layer
	{
		RasterizerState _rasterizerState ~ _?.ReleaseRef();
		RasterizerState _rasterizerStateClockWise ~ _?.ReleaseRef();

		GraphicsContext _context ~ _?.ReleaseRef();
		DepthStencilTarget _swapchainDepthBuffer ~ _?.ReleaseRef();
		
		BlendState _alphaBlendState ~ _?.ReleaseRef();
		BlendState _opaqueBlendState ~ _?.ReleaseRef();
		
		EcsWorld _world = new EcsWorld() ~ delete _;

		Editor _editor ~ delete _;

		PerspectiveCameraController _cameraController ~ delete _;
		
		RenderTarget2D _renderTarget2D ~ _?.ReleaseRef();

		public this() : base("Example")
		{
			Application.Get().Window.IsVSync = false;

			InitGraphics();
			InitEcs();
			InitEditor();
		}

		private void InitGraphics()
		{
			_context = Application.Get().Window.Context..AddRef();
			
			_swapchainDepthBuffer = new DepthStencilTarget(_context, _context.SwapChain.Width, _context.SwapChain.Height);
			
			RasterizerStateDescription rsDesc = .(.Solid, .Back, true);
			_rasterizerState = new RasterizerState(_context, rsDesc);

			rsDesc.FrontCounterClockwise = false;
			_rasterizerStateClockWise = new RasterizerState(_context, rsDesc);

			BlendStateDescription blendDesc = .();
			blendDesc.RenderTarget[0] = .(true, .SourceAlpha, .InvertedSourceAlpha, .Add, .SourceAlpha, .InvertedSourceAlpha, .Add, .All);
			_alphaBlendState = new BlendState(_context, blendDesc);
			_opaqueBlendState = new BlendState(_context, .Default);

			_renderTarget2D = new RenderTarget2D(_context, RenderTarget2DDescription(.R8G8B8A8_UNorm, 100, 100) {DepthStencilFormat = .D32_Float});

			SamplerStateDescription desc = .();

			SamplerState sampler = new SamplerState(_context, desc);

			_renderTarget2D.SamplerState = sampler;

			sampler.ReleaseRef();
		}

		private void InitEcs()
		{
			_world.Register<DebugNameComponent>();
			_world.Register<TransformComponent>();
			_world.Register<ParentComponent>();
			_world.Register<MeshComponent>();
			_world.Register<MeshRendererComponent>();
			_world.Register<SkinnedMeshRendererComponent>();
			_world.Register<CameraComponent>();
			_world.Register<AnimationComponent>();
		}

		private void InitEditor()
		{
			_editor = new Editor(_world);
			_editor.SceneViewportWindow.ViewportSizeChangedEvent.Add(new (s, e) => ViewportSizeChanged(s, e));

			_cameraController = new .(Application.Get().Window.Context.SwapChain.BackbufferViewport.Width /
									Application.Get().Window.Context.SwapChain.BackbufferViewport.Height);
			_cameraController.CameraPosition = .(0, 0, -5);
			_cameraController.TranslationSpeed = 10;
			

			_editor.[Friend]CreateEntityWithTransform();
		}
		
		public override void Update(GameTime gameTime)
		{
			if(_editor.SceneViewportWindow.HasFocus && Input.IsMouseButtonPressed(.RightButton))
				_cameraController.Update(gameTime);

			TransformSystem.Update(_world);

			RenderCommand.Clear(_renderTarget2D, .(0.2f, 0.2f, 0.2f));
			RenderCommand.Clear(_renderTarget2D, 1.0f, 0, .Depth);

			_context.SetRenderTarget(_renderTarget2D);
			_context.BindRenderTargets();

			RenderCommand.SetViewport(Viewport(0, 0, _renderTarget2D.Width, _renderTarget2D.Height));

			_opaqueBlendState.Bind();

			Renderer.BeginScene(_cameraController.Camera);

			DebugRenderer.Render(_world);
			
			Renderer.EndScene();

			RenderCommand.Clear(null, .(0.2f, 0.2f, 0.2f));
			_swapchainDepthBuffer.Clear(1.0f, 0, .Depth);

			_context.SetRenderTarget(null);
			_swapchainDepthBuffer.Bind();
			_context.BindRenderTargets();

			RenderCommand.SetViewport(_context.SwapChain.BackbufferViewport);
		}

		public override void OnEvent(Event event)
		{
			_cameraController.OnEvent(event);

			EventDispatcher dispatcher = EventDispatcher(event);

			dispatcher.Dispatch<ImGuiRenderEvent>(scope (e) => OnImGuiRender(e));
			dispatcher.Dispatch<WindowResizeEvent>(scope (e) => OnWindowResize(e));
		}

		ImGui.ID _mainDockspaceId;

		private bool OnImGuiRender(ImGuiRenderEvent event)
		{
			ImGui.Viewport* viewport = ImGui.GetMainViewport();
			ImGui.DockSpaceOverViewport(viewport);

			DrawMainMenuBar();

			_editor.SceneViewportWindow.RenderTarget = _renderTarget2D;

			_editor.Update();

			return false;
		}

		private void DrawMainMenuBar()
		{
			ImGui.BeginMainMenuBar();

			if(ImGui.BeginMenu("File", false))
			{
				ImGui.EndMenu();
			}
			
			if(ImGui.BeginMenu("View", true))
			{
				if(ImGui.MenuItem(EntityHierarchyWindow.s_WindowTitle))
				{
					_editor.EntityHierarchyWindow.Open = true;
				}

				if(ImGui.MenuItem(ComponentEditWindow.s_WindowTitle))
				{
					_editor.ComponentEditWindow.Open = true;
				}

				if(ImGui.MenuItem(SceneViewportWindow.s_WindowTitle))
				{
					_editor.SceneViewportWindow.Open = true;
				}

				ImGui.EndMenu();
			}


			ImGui.EndMainMenuBar();
		}

		private bool OnWindowResize(WindowResizeEvent e)
		{
			_swapchainDepthBuffer.ReleaseRef();
			_swapchainDepthBuffer = new DepthStencilTarget(_context, _context.SwapChain.Width, _context.SwapChain.Height);

			return false;
		}

		private void ViewportSizeChanged(Object sender, Vector2 viewportSize)
		{
			uint32 sizeX = (uint32)viewportSize.X;
			uint32 sizeY = (uint32)viewportSize.Y;

			if(sizeX == 0 || sizeY == 0)
				return;

			_renderTarget2D.Resize(sizeX, sizeY);

			_cameraController.AspectRatio = (float)sizeX / (float)sizeY;
		}
	}
}
