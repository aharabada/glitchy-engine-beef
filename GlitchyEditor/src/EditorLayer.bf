using System;
using ImGui;
using GlitchyEngine;
using GlitchyEditor.EditWindows;
using GlitchyEngine.Events;
using GlitchyEngine.ImGui;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using GlitchyEngine.World;
using GlitchyEngine.Content;
using System.Collections;
using GlitchyEngine.Renderer.Animation;
using System.IO;
using GlitchyEngine.Core;

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
		String _sceneFilePath = new String() ~ delete _;

		public String SceneFilePath
		{
			get => _sceneFilePath;
			set
			{
				_sceneFilePath.Clear();

				if (value != null)
					_sceneFilePath.Append(value);
			}
		}

		Editor _editor ~ delete _;

		RenderTarget2D _cameraTarget ~ _.ReleaseRef();
		RenderTargetGroup _viewportTarget ~ _.ReleaseRef();

		SettingsWindow _settingsWindow = new .() ~ delete _;

		EditorCamera _camera ~ _.Dispose();

		Texture2D _editorIcons ~ _.ReleaseRef();
		SubTexture2D _iconDirectionalLight ~ _.ReleaseRef();
		SubTexture2D _iconCamera ~ _.ReleaseRef();

		public this() : base("Example")
		{
			Application.Get().Window.IsVSync = false;

			InitGraphics();

			_camera = EditorCamera(Vector3(3.5f, 1.25f, 2.75f), Quaternion.FromEulerAngles(MathHelper.ToRadians(40), MathHelper.ToRadians(25), 0), MathHelper.ToRadians(75), 0.1f, 1);
			_camera.RenderTarget = _cameraTarget;

			NewScene();

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
			
			_cameraTarget = new RenderTarget2D(RenderTarget2DDescription(.R16G16B16A16_Float, 100, 100) {DepthStencilFormat = .D32_Float});
			_cameraTarget.SamplerState = SamplerStateManager.LinearClamp;

			//_viewportTarget = new RenderTarget2D(RenderTarget2DDescription(.R8G8B8A8_UNorm, 100, 100));
			//_viewportTarget.SamplerState = SamplerStateManager.LinearClamp;

			_viewportTarget = new RenderTargetGroup(.()
				{
					Width = 100,
					Height = 100,
					ColorTargetDescriptions = TargetDescription[](
						.(.R8G8B8A8_UNorm))
				});

			_editorIcons = new Texture2D("Textures/EditorIcons.dds");
			_editorIcons.SamplerState = SamplerStateManager.AnisotropicClamp;
			_iconDirectionalLight = .CreateFromGrid(_editorIcons, .(0, 0), .(64, 64));
			_iconCamera = .CreateFromGrid(_editorIcons, .(1, 0), .(64, 64));
		}

		private void InitEditor()
		{
			_editor = new Editor(_scene);
			_editor.SceneViewportWindow.ViewportSizeChangedEvent.Add(new (s, e) => ViewportSizeChanged(s, e));
			_editor.CurrentCamera = &_camera;
		}
		
		public override void Update(GameTime gameTime)
		{
			_camera.Update(gameTime);

			// Clear the swapchain-buffer
			RenderCommand.Clear(null, .Color | .Depth, .(0.2f, 0.2f, 0.2f), 1.0f, 0);

			RenderCommand.Clear(_viewportTarget, .Color | .Depth, .(0.2f, 0.2f, 0.2f), 1.0f, 0);

			RenderCommand.SetRenderTargetGroup(_viewportTarget, true);
			RenderCommand.BindRenderTargets();

			RenderCommand.SetViewport(Viewport(0, 0, _viewportTarget.Width, _viewportTarget.Height));

			RenderCommand.SetBlendState(_alphaBlendState);
			RenderCommand.SetDepthStencilState(_depthStencilState);

			_scene.UpdateEditor(gameTime, _camera, _viewportTarget, scope => DebugDraw3D, scope => DebugDraw2D);

			RenderCommand.UnbindRenderTargets();
			RenderCommand.SetRenderTarget(null, 0, true);
			RenderCommand.BindRenderTargets();

			RenderCommand.SetViewport(_context.SwapChain.BackbufferViewport);
		}

		private void DebugDraw3D()
		{
			/*for (var (entity, transform, camera) in _scene.[Friend]_ecsWorld.Enumerate<TransformComponent, CameraComponent>())
			{
				if (_editor.EntityHierarchyWindow.SelectedEntities.Contains(.(entity, _scene)))
				{
					DebugRenderer.DrawViewFrustum(transform.WorldTransform, camera.Camera.Projection);
				}
			}*/
		}

		private void DebugDraw2D()
		{
			RenderCommand.SetBlendState(_alphaBlendState);
			
			Matrix billboard = _camera.View.Invert();
			billboard.Translation = .Zero;

			Matrix Billboard(Matrix transform)
			{
				Vector3 worldPos = transform.Translation;

				return Matrix.Translation(worldPos) * billboard;
			}

			for (var (entity, transform, camera) in _scene.[Friend]_ecsWorld.Enumerate<TransformComponent, CameraComponent>())
			{
				if (_editor.EntityHierarchyWindow.SelectedEntities.Contains(.(entity, _scene)))
				{
					DebugRenderer.DrawViewFrustum(transform.WorldTransform, camera.Camera.Projection, _camera.Projection * _camera.View);
				}
				
				Matrix world = Billboard(transform.WorldTransform);

				Renderer2D.DrawQuad(world, _iconCamera);
			}

			for (var (entity, transform, light) in _scene.[Friend]_ecsWorld.Enumerate<TransformComponent, LightComponent>())
			{
				if (_editor.EntityHierarchyWindow.SelectedEntities.Contains(.(entity, _scene)))
				{
					Renderer.DrawRay(.Zero, .(0, 0, 20), ColorRGBA(light.SceneLight.Color, 1.0f), transform.WorldTransform);

					for (float angle = 0; angle < MathHelper.TwoPi; angle += MathHelper.TwoPi / 5.0f)
					{
						Vector2 pos = MathHelper.CirclePoint(angle, 0.5f);

						Renderer.DrawRay(.(pos, 0), .(pos, 20), .White, transform.WorldTransform);
					}
				}

				Matrix world = Billboard(transform.WorldTransform);

				Renderer2D.DrawQuad(world, _iconDirectionalLight, ColorRGBA(light.SceneLight.Color, 1.0f));
			}
		}

		public override void OnEvent(Event event)
		{
			EventDispatcher dispatcher = EventDispatcher(event);

			dispatcher.Dispatch<ImGuiRenderEvent>(scope (e) => OnImGuiRender(e));
			dispatcher.Dispatch<WindowResizeEvent>(scope (e) => OnWindowResize(e));
			dispatcher.Dispatch<KeyPressedEvent>(scope (e) => OnKeyPressed(e));
			dispatcher.Dispatch<MouseScrolledEvent>(scope (e) => OnMouseScrolled(e));
		}

		ImGui.ID _mainDockspaceId;
		
		TextureViewer viewer = new TextureViewer() ~ delete _;

		private bool OnImGuiRender(ImGuiRenderEvent event)
		{
			//viewer.ViewTexture(Renderer.[Friend]_gBuffer.Albedo);

			ImGui.Viewport* viewport = ImGui.GetMainViewport();
			ImGui.DockSpaceOverViewport(viewport);

			DrawMainMenuBar();

			_editor.SceneViewportWindow.RenderTarget = _viewportTarget;

			_editor.Update();

			_settingsWindow.Show();

			return false;
		}

		// Just for testing
		private void TestEntitiesWithModels()
		{
			{
				var lightNtt = _scene.CreateEntity("My Sexy Sun 2");
				let transform = lightNtt.GetComponent<TransformComponent>();
				transform.Position = .(0, 0, 0);
				transform.RotationEuler = .(MathHelper.ToRadians(70), MathHelper.ToRadians(-30), 0);

				let light = lightNtt.AddComponent<LightComponent>();
				light.SceneLight.Illuminance = 10.0f;
				light.SceneLight.Color = .(1.0f, 0.95f, 0.8f);
			}

			{
				var lightNtt = _scene.CreateEntity("My Sexy Sun 3");
				let transform = lightNtt.GetComponent<TransformComponent>();
				transform.Position = .(0, 0, 0);
				transform.RotationEuler = .(MathHelper.ToRadians(20), MathHelper.ToRadians(-55), 0);

				let light = lightNtt.AddComponent<LightComponent>();
				light.SceneLight.Illuminance = 10.0f;
				light.SceneLight.Color = .(1.0f, 0.95f, 0.8f);
			}

			{
				var cameraNtt = _scene.CreateEntity("My Camera");
				let transform = cameraNtt.GetComponent<TransformComponent>();
				transform.Position = .(5, 5, -5);
				transform.RotationEuler = .(MathHelper.ToRadians(45), MathHelper.ToRadians(-45), 0);

				let camera = cameraNtt.AddComponent<CameraComponent>();
				camera.Primary = true;
				camera.Camera.SetPerspective(MathHelper.ToRadians(45), 0.1f, 10.0f);
			}

			var fxLib = Application.Get().EffectLibrary;

			using (Effect myEffect = fxLib.Load("content/Shaders/myEffect.hlsl"))
			/*using (Texture2D albedo = new Texture2D("Textures/White.png", true))
			using (Texture2D normal = new Texture2D("Textures/White.png"))
			using (Texture2D rough = new Texture2D("Textures/White.png"))
			using (Texture2D metal = new Texture2D("Textures/White.png"))*/
			using (Texture2D albedo = new Texture2D("Textures/TestMat/rustediron2_albedo.png", true))
			using (Texture2D normal = new Texture2D("Textures/TestMat/rustediron2_normal.png"))
			using (Texture2D rough = new Texture2D("Textures/TestMat/rustediron2_roughness.png"))
			using (Texture2D metal = new Texture2D("Textures/TestMat/rustediron2_metallic.png"))
			{
				albedo.SamplerState = SamplerStateManager.AnisotropicWrap;
				normal.SamplerState = SamplerStateManager.AnisotropicWrap;
				rough.SamplerState = SamplerStateManager.AnisotropicWrap;
				metal.SamplerState = SamplerStateManager.AnisotropicWrap;
				
				List<AnimationClip> clips = scope .();

				using (Material mat = new .(myEffect))
				{
					mat.SetTexture("AlbedoTexture", albedo);
					mat.SetTexture("NormalTexture", normal);
					mat.SetTexture("MetallicTexture", metal);
					mat.SetTexture("RoughnessTexture", rough);

					mat.SetVariable("AlbedoColor", ColorRGBA.White);
					mat.SetVariable("NormalScaling", Vector2.One);
					mat.SetVariable("MetallicFactor", 1.0f);
					mat.SetVariable("RoughnessFactor", 1.0f);
		
					EcsEntity e = ModelLoader.LoadModel("content/Models/sphere.glb", myEffect, mat, _scene.[Friend]_ecsWorld, clips, "Sphere 1");
					
					Entity entity = .(e, _scene);
					var transform = entity.GetComponent<TransformComponent>();
					transform.Position = .(5, 0, 5);
				}
				
				/*using (Material mat = new .(myEffect))
				{
					mat.SetTexture("AlbedoTexture", albedo);
					mat.SetTexture("NormalTexture", normal);
					mat.SetTexture("MetallicTexture", metal);
					mat.SetTexture("RoughnessTexture", rough);
					//mat.SetVariable("BaseColor", Vector4(1, 1, 0, 1));
					//mat.SetVariable("LightDir", Vector3(0, 1, 0).Normalized());
		
		
					ModelLoader.LoadModel("content/Models/sphere.glb", myEffect, mat, _scene.[Friend]_ecsWorld, clips);
				}*/

				ClearAndReleaseItems!(clips);
			}

			using (Effect myEffect = fxLib.Get("myEffect"))
			using (Texture2D white = new Texture2D("Textures/White.png"))
			using (Texture2D normal = new Texture2D("Textures/DefaultNormal.png"))
			{
				white.SamplerState = SamplerStateManager.PointClamp;
				normal.SamplerState = SamplerStateManager.PointClamp;

				List<AnimationClip> clips = scope .();

				for (int x < 10)
				for (int y < 10)
				{
					using (Material mat = new .(myEffect))
					{
						mat.SetTexture("AlbedoTexture", white);
						mat.SetTexture("NormalTexture", normal);
						mat.SetTexture("MetallicTexture", white);
						mat.SetTexture("RoughnessTexture", white);

						mat.SetVariable("AlbedoColor", Vector4(1, 0, 0, 1));
						mat.SetVariable("NormalScaling", Vector2(1.0f));
						mat.SetVariable("RoughnessFactor", (x + 1) / 10.0f);
						mat.SetVariable("MetallicFactor", y / 9.0f);
			
						EcsEntity e = ModelLoader.LoadModel("content/Models/sphere.glb", myEffect, mat, _scene.[Friend]_ecsWorld, clips, scope $"Sphere {x} {y}");

						Entity entity = .(e, _scene);
						var transform = entity.GetComponent<TransformComponent>();
						transform.Position = .(x * 1.5f, y * 1.5f, 0);
					}
				}

				ClearAndReleaseItems!(clips);
			}
		}

		/// Creates a new scene.
		private void NewScene()
		{
			SceneFilePath = null;

			_camera.Position = .(-1.5f, 1.5f, -2.5f);
			_camera.RotationEuler = .(MathHelper.ToRadians(25), MathHelper.ToRadians(35), 0);

			// Create the default light source
			{
				var lightNtt = _scene.CreateEntity("Light");
				let transform = lightNtt.GetComponent<TransformComponent>();
				transform.Position = .(0, 0, 0);
				transform.RotationEuler = .(MathHelper.ToRadians(45), MathHelper.ToRadians(-100), 0);

				let light = lightNtt.AddComponent<LightComponent>();
				light.SceneLight.Illuminance = 10.0f;
				light.SceneLight.Color = .(1.0f, 0.95f, 0.8f);
			}

			TestEntitiesWithModels();
		}
		
		/// Saves the scene in the file that is was loaded from or saved to last. If there is no such path (i.e. it is a new scene) the save file dialog will open.
		private void SaveScene()
		{
			if (String.IsNullOrWhiteSpace(SceneFilePath))
			{
				SaveSceneAs();
				return;
			}
			
			SceneSerializer serializer = scope .(_scene);
			serializer.Serialize(SceneFilePath);
		}
		
		/// Opens a save file dialog and saves the scene at the user specified location.
		private void SaveSceneAs()
		{
			SaveFileDialog sfd = scope .();
			if (sfd.ShowDialog() case .Ok(let val))
			{
				if (val == .OK)
				{
					SceneFilePath = sfd.FileNames[0];

					SaveScene();
				}
			}
		}
		
		/// Opens a open file dialog and load the scene selected by the user specified.
		private void OpenScene()
		{
			OpenFileDialog ofd = scope .();
			if (ofd.ShowDialog() case .Ok(let val))
			{
				if (val == .OK)
				{
					SceneFilePath = ofd.FileNames[0];

					delete _scene;
					_scene = new Scene();

					SceneSerializer serializer = scope .(_scene);
					serializer.Deserialize(SceneFilePath);

					_editor.CurrentScene = _scene;
				}
			}
		}

		private void DrawMainMenuBar()
		{
			ImGui.BeginMainMenuBar();

			if(ImGui.BeginMenu("File", true))
			{
				if (ImGui.MenuItem("New", "Ctrl+N"))
					NewScene();

				if (ImGui.MenuItem("Save", "Ctrl+S"))
					SaveScene();

				if (ImGui.MenuItem("Save as...", "Ctrl+Shift+N"))
					SaveSceneAs();

				if (ImGui.MenuItem("Open...", "Ctrl+O"))
					OpenScene();

				ImGui.Separator();

				if (ImGui.MenuItem("Settings"))
					_settingsWindow.Open = true;
				
				ImGui.Separator();
				
				if (ImGui.MenuItem("Exit"))
					Application.Get().Close();

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
			_cameraTarget.Resize(sizeX, sizeY);

			_scene.OnViewportResize(sizeX, sizeY);
			_camera.OnViewportResize(sizeX, sizeY);
		}

		private bool OnKeyPressed(KeyPressedEvent e)
		{
			bool control = Input.IsKeyPressed(Key.Control);
			bool shift = Input.IsKeyPressed(Key.Shift);
			
			if (!_camera.[Friend]BindMouse && control)
			{
				switch (e.KeyCode)
				{
				case .N:
					NewScene();
					return true;
				case .O:
					OpenScene();
					return true;
				case .S:
					if (shift)
						SaveSceneAs();
					else
						SaveScene();
					
					return true;
				default:
				}
			}

			return false;
		}

		private bool OnMouseScrolled(MouseScrolledEvent e)
		{
			if (_camera.OnMouseScrolled(e))
				return true;

			return false;
		}
	}
}
