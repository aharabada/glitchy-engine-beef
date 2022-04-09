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

		GraphicsContext _context ~ _.ReleaseRef();
		
		BlendState _alphaBlendState ~ _.ReleaseRef();
		BlendState _opaqueBlendState ~ _.ReleaseRef();
		DepthStencilState _depthStencilState ~ _.ReleaseRef();
		
		Scene _scene = new Scene() ~ delete _;

		Editor _editor ~ delete _;

		RenderTarget2D _viewportTarget ~ _?.ReleaseRef();

		Entity _cameraEntity;
		Entity _otherCameraEntity;

		class CameraController : ScriptableEntity
		{
			protected override void OnCreate()
			{
				Log.EngineLogger.Trace("Cam controller created!");
			}

			protected override void OnUpdate(GameTime gameTime)
			{
				var transformCmp = GetComponent<TransformComponent>();

				Vector3 position = transformCmp.Position;

				if (Input.IsKeyPressed(Key.A))
				{
					position.X -= gameTime.DeltaTime;
				}
				if (Input.IsKeyPressed(Key.D))
				{
					position.X += gameTime.DeltaTime;
				}
				if (Input.IsKeyPressed(Key.W))
				{
					position.Y += gameTime.DeltaTime;
				}
				if (Input.IsKeyPressed(Key.S))
				{
					position.Y -= gameTime.DeltaTime;
				}

				transformCmp.Position = position;
			}

			protected override void OnDestroy()
			{
				Log.EngineLogger.Trace("Cam controller destroyed!");
			}
		}

		public this() : base("Example")
		{
			Application.Get().Window.IsVSync = false;

			InitGraphics();

			{
				_cameraEntity = _scene.CreateEntity("Camera Entity");
				let camera = _cameraEntity.AddComponent<CameraComponent>();
				camera.Camera.SetPerspective(MathHelper.ToRadians(75), 0.1f, 10000.0f);
				camera.Primary = true;
				camera.FixedAspectRatio = false;
				let transform = _cameraEntity.GetComponent<TransformComponent>();
				transform.Position = .(0, 0, -5);

				_cameraEntity.AddComponent<NativeScriptComponent>().Bind<EditorCameraController>();
				_cameraEntity.AddComponent<EditorComponent>();
			}

			{
				_otherCameraEntity = _scene.CreateEntity("Other Camera Entity");
				let camera = _otherCameraEntity.AddComponent<CameraComponent>();
				camera.Camera.SetPerspective(MathHelper.ToRadians(45), 0.1f, 1000.0f);
				camera.Primary = false;
				camera.FixedAspectRatio = false;
				let transform = _otherCameraEntity.GetComponent<TransformComponent>();
				transform.Position = .(0, 0, -5);

				_otherCameraEntity.AddComponent<NativeScriptComponent>().Bind<EditorCameraController>();
				_otherCameraEntity.AddComponent<EditorComponent>();
			}

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

			DepthStencilStateDescription dsDesc = .();
			_depthStencilState = new DepthStencilState(dsDesc);

			_viewportTarget = new RenderTarget2D(RenderTarget2DDescription(.R8G8B8A8_UNorm, 100, 100) {DepthStencilFormat = .D32_Float});
			_viewportTarget.SamplerState = SamplerStateManager.LinearClamp;
		}

		private void InitEditor()
		{
			_editor = new Editor(_scene);
			_editor.SceneViewportWindow.ViewportSizeChangedEvent.Add(new (s, e) => ViewportSizeChanged(s, e));

			//_editor.[Friend]CreateEntityWithTransform();

			_editor.SceneViewportWindow.CameraEntity = _cameraEntity;
		}
		
		public override void Update(GameTime gameTime)
		{
			var scriptComponent = _cameraEntity.GetComponent<NativeScriptComponent>();

			if (var camController = scriptComponent.Instance as EditorCameraController)
			{
				camController.IsEnabled = (_editor.SceneViewportWindow.HasFocus && Input.IsMouseButtonPressed(.RightButton));
			}

			//TransformSystem.Update(_world);

			RenderCommand.Clear(_viewportTarget, .Color | .Depth, .(0.2f, 0.2f, 0.2f), 1.0f, 0);

			RenderCommand.SetRenderTarget(_viewportTarget, 0, true);
			RenderCommand.BindRenderTargets();

			RenderCommand.SetViewport(Viewport(0, 0, _viewportTarget.Width, _viewportTarget.Height));

			RenderCommand.SetBlendState(_alphaBlendState);
			RenderCommand.SetDepthStencilState(_depthStencilState);

			//Renderer.BeginScene(_cameraController.Camera);

			//DebugRenderer.Render(_scene.[Friend]_ecsWorld);
			
			//Renderer.EndScene();

			_scene.Update(gameTime);

			RenderCommand.Clear(null, .Color | .Depth, .(0.2f, 0.2f, 0.2f), 1.0f, 0);

			RenderCommand.SetRenderTarget(null, 0, true);
			RenderCommand.BindRenderTargets();

			RenderCommand.SetViewport(_context.SwapChain.BackbufferViewport);
		}

		public override void OnEvent(Event event)
		{
			EventDispatcher dispatcher = EventDispatcher(event);

			dispatcher.Dispatch<ImGuiRenderEvent>(scope (e) => OnImGuiRender(e));
			dispatcher.Dispatch<WindowResizeEvent>(scope (e) => OnWindowResize(e));
		}

		ImGui.ID _mainDockspaceId;

		private bool OnImGuiRender(ImGuiRenderEvent event)
		{
			ImGui.Begin("Test");

			static bool cameraA = true;

			if (ImGui.Checkbox("Camera A", &cameraA))
			{
				_cameraEntity.GetComponent<CameraComponent>().Primary = cameraA;
				_otherCameraEntity.GetComponent<CameraComponent>().Primary = !cameraA;
			}

			ImGui.End();

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

			_scene.OnViewportResize(sizeX, sizeY);
		}
	}
}
