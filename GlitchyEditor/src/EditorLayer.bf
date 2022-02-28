using System;
using ImGui;
using GlitchyEngine;
using GlitchyEditor.EditWindows;
using GlitchyEngine.Events;
using GlitchyEngine.ImGui;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using GlitchyEngine.World;

namespace GlitchyEditor
{
	class EditorLayer : Layer
	{
		RasterizerState _rasterizerState ~ _?.ReleaseRef();
		RasterizerState _rasterizerStateClockWise ~ _?.ReleaseRef();

		GraphicsContext _context ~ _?.ReleaseRef();
		
		BlendState _alphaBlendState ~ _?.ReleaseRef();
		BlendState _opaqueBlendState ~ _?.ReleaseRef();
		
		Scene _scene = new Scene() ~ delete _;

		Editor _editor ~ delete _;

		PerspectiveCameraController _cameraController ~ delete _;
		
		RenderTarget2D _viewportTarget ~ _?.ReleaseRef();

		public this() : base("Example")
		{
			Application.Get().Window.IsVSync = false;

			InitGraphics();
			//InitEcs();
			InitEditor();
		}

		private void InitGraphics()
		{
			_context = Application.Get().Window.Context..AddRef();
			
			RasterizerStateDescription rsDesc = .(.Solid, .Back, true);
			_rasterizerState = new RasterizerState(rsDesc);

			rsDesc.FrontCounterClockwise = false;
			_rasterizerStateClockWise = new RasterizerState(rsDesc);

			BlendStateDescription blendDesc = .();
			blendDesc.RenderTarget[0] = .(true, .SourceAlpha, .InvertedSourceAlpha, .Add, .SourceAlpha, .InvertedSourceAlpha, .Add, .All);
			_alphaBlendState = new BlendState(blendDesc);
			_opaqueBlendState = new BlendState(.Default);

			_viewportTarget = new RenderTarget2D(RenderTarget2DDescription(.R8G8B8A8_UNorm, 100, 100) {DepthStencilFormat = .D32_Float});
			_viewportTarget.SamplerState = SamplerStateManager.LinearClamp;
		}

		/*private void InitEcs()
		{
			_world.Register<DebugNameComponent>();
			_world.Register<TransformComponent>();
			_world.Register<ParentComponent>();
			_world.Register<MeshComponent>();
			_world.Register<MeshRendererComponent>();
			_world.Register<SkinnedMeshRendererComponent>();
			_world.Register<CameraComponent>();
			_world.Register<AnimationComponent>();
		}*/

		private void InitEditor()
		{
			_editor = new Editor(_scene);
			_editor.SceneViewportWindow.ViewportSizeChangedEvent.Add(new (s, e) => ViewportSizeChanged(s, e));

			_cameraController = new .(_context.SwapChain.AspectRatio);
			_cameraController.CameraPosition = .(0, 0, -5);
			_cameraController.TranslationSpeed = 10;

			//_editor.[Friend]CreateEntityWithTransform();

			_editor.SceneViewportWindow._camera = _cameraController.Camera;
		}
		
		public override void Update(GameTime gameTime)
		{
			if(_editor.SceneViewportWindow.HasFocus && Input.IsMouseButtonPressed(.RightButton))
				_cameraController.Update(gameTime);

			//TransformSystem.Update(_world);

			RenderCommand.Clear(_viewportTarget, .Color | .Depth, .(0.2f, 0.2f, 0.2f), 1.0f, 0);

			RenderCommand.SetRenderTarget(_viewportTarget);
			RenderCommand.BindRenderTargets();

			RenderCommand.SetViewport(Viewport(0, 0, _viewportTarget.Width, _viewportTarget.Height));

			RenderCommand.SetBlendState(_opaqueBlendState);

			//Renderer.BeginScene(_cameraController.Camera);

			//DebugRenderer.Render(_scene.[Friend]_ecsWorld);
			
			//Renderer.EndScene();

			Renderer2D.BeginScene(_cameraController.Camera);
			
			_scene.Update(gameTime);
			
			Renderer2D.EndScene();


			RenderCommand.Clear(null, .Color | .Depth, .(0.2f, 0.2f, 0.2f), 1.0f, 0);

			RenderCommand.SetRenderTarget(null);
			RenderCommand.BindRenderTargets();

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

			_editor.SceneViewportWindow.RenderTarget = _viewportTarget;

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
			return false;
		}

		private void ViewportSizeChanged(Object sender, Vector2 viewportSize)
		{
			uint32 sizeX = (uint32)viewportSize.X;
			uint32 sizeY = (uint32)viewportSize.Y;

			if(sizeX == 0 || sizeY == 0)
				return;

			_viewportTarget.Resize(sizeX, sizeY);

			_cameraController.AspectRatio = (float)sizeX / (float)sizeY;
		}
	}
}
