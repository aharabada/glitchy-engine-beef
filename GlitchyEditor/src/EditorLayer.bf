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
using GlitchyEditor.Assets;
using GlitchyEngine.Scripting;

namespace GlitchyEditor
{
	class EditorLayer : Layer
	{
		enum SceneState
		{
			Edit,
			Play,
			Simulate
		}

		RasterizerState _rasterizerState ~ _?.ReleaseRef();
		RasterizerState _rasterizerStateClockWise ~ _?.ReleaseRef();

		// TODO: we shouldn't hold a reference to the context
		GraphicsContext _context ~ _.ReleaseRef();
		
		BlendState _alphaBlendState ~ _.ReleaseRef();
		BlendState _opaqueBlendState ~ _.ReleaseRef();
		DepthStencilState _depthStencilState ~ _.ReleaseRef();

		/// Reference to the scene that is currently being played and worked on.
		Scene _activeScene ~ _?.ReleaseRef();
		
		/**
		 * Referece to the editor scene.
		 * We hold a reference to the editor scene because we need it in order
		 * to restore the original state once we stop the game/simulation.
		 * Before starting the simulation the editor scene will be copied and
		 * the reference in _activeScene will be replaced with the new scene.
		 */
		Scene _editorScene ~ _?.ReleaseRef();

		SceneRenderer _gameSceneRenderer ~ delete _;
		SceneRenderer _editorSceneRenderer ~ delete _;
		
		/// Path of the current scene.
		append String _sceneFilePath = .();

		Editor _editor ~ delete _;

		RenderTargetGroup _cameraTarget ~ _.ReleaseRef();
		RenderTargetGroup _editorViewportTarget ~ _.ReleaseRef();
		RenderTargetGroup _gameViewportTarget ~ _.ReleaseRef();

		SettingsWindow _settingsWindow = new .() ~ delete _;

		EditorCamera _camera ~ _.Dispose();

		EditorIcons _editorIcons ~ _.ReleaseRef();

		EditorContentManager _contentManager;

		SceneState _sceneState = .Edit;
		bool _isPaused = false;
		
		append List<(String Name, String Path)> _recentProjectPaths = .() ~ {
				for (var item in _)
				{
					delete item.Name;
					delete item.Path;
				}
			};
		
		/// Gets or sets the path of the current scene.
		public StringView SceneFilePath
		{
			get => _sceneFilePath;
			set
			{
				_sceneFilePath.Clear();

				if (!value.IsWhiteSpace)
					_sceneFilePath.Append(value);
			}
		}

		public this(String[] args, EditorContentManager contentManager) : base("Editor")
		{
			Application.Get().Window.IsVSync = true;

			_contentManager = contentManager;

			InitGraphics();

			_gameSceneRenderer = new SceneRenderer();
			_editorSceneRenderer = new SceneRenderer();

			_camera = EditorCamera(float3(-3f, 3f, -3f), Quaternion.FromEulerAngles(MathHelper.ToRadians(40), MathHelper.ToRadians(25), 0), MathHelper.ToRadians(75), 0.1f, 1);
			_camera.RenderTarget = _cameraTarget;
			
			InitEditor();

			if (args.Count >= 1)
				LoadSceneFile(args[0]);

			// Create a new scene, if LoadSceneFile failed
			if (_activeScene == null)
				NewScene();
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
			
			_cameraTarget = new RenderTargetGroup(.(){
					Width = 100,
					Height = 100,
					ColorTargetDescriptions = TargetDescription[](
						.(.R16G16B16A16_Float),
						.(.R32_UInt)
					),
					DepthTargetDescription = .(.D24_UNorm_S8_UInt)
				});

			_editorViewportTarget = new RenderTargetGroup(.()
				{
					Width = 100,
					Height = 100,
					ColorTargetDescriptions = TargetDescription[](
						.(.R8G8B8A8_UNorm))
				});

			_gameViewportTarget = new RenderTargetGroup(.()
				{
					Width = 100,
					Height = 100,
					ColorTargetDescriptions = TargetDescription[](
						.(.R8G8B8A8_UNorm))
				});

			_editorIcons = new EditorIcons("Textures/EditorIcons.dds", .(64, 64));
			_editorIcons.SamplerState = SamplerStateManager.AnisotropicClamp;

			ContentBrowserWindow.s_FolderTexture = _editorIcons.Folder;
			ContentBrowserWindow.s_FileTexture = _editorIcons.File;
		}

		private void InitEditor()
		{
			_editor = new Editor(_editorScene, _contentManager);
			_editor.SceneViewportWindow.ViewportSizeChanged.Add(new (s, e) => EditorViewportSizeChanged(s, e));
			_editor.GameViewportWindow.ViewportSizeChanged.Add(new (s, e) => GameViewportSizeChanged(s, e));
			_editor.CurrentCamera = &_camera;
			_editor.GameSceneRenderer = _gameSceneRenderer;
			_editor.EditorSceneRenderer = _editorSceneRenderer;

			_editor.RequestOpenScene.Add(new (s, fileName) => {
			  LoadSceneFile(fileName);
			});
		}
		
		public override void Update(GameTime gameTime)
		{
			Debug.Profiler.ProfileFunction!();

			_editor.CurrentScene = _activeScene;

			Scene.UpdateMode updateMode;

			switch (_sceneState)
			{
			case .Edit:
				updateMode = .Editor;
			case .Play:
				updateMode = .Runtime;
			case .Simulate:
				updateMode = .Physics;
			}

			if (_sceneState != .Edit && _isPaused)
				updateMode = .None;

			_activeScene.Update(gameTime, updateMode);

			// Clear the swapchain-buffer
			RenderCommand.Clear(null, .Color | .Depth, .(0.2f, 0.2f, 0.2f), 1.0f, 0);
			
			RenderCommand.SetBlendState(_alphaBlendState);
			RenderCommand.SetDepthStencilState(_depthStencilState);

			if (_editor.GameViewportWindow.Visible)
			{
				_gameSceneRenderer.Scene = _activeScene;

				_activeScene.SetViewportSize((uint32)_editor.GameViewportWindow.ViewportSize.X, (uint32)_editor.GameViewportWindow.ViewportSize.Y);
				_gameSceneRenderer.SetViewportSize((uint32)_editor.GameViewportWindow.ViewportSize.X, (uint32)_editor.GameViewportWindow.ViewportSize.Y);

				RenderCommand.Clear(_gameViewportTarget, .Color | .Depth, .(0.2f, 0.2f, 0.2f), 1.0f, 0);
				_gameSceneRenderer.RenderRuntime(gameTime, _gameViewportTarget);
			}

			RenderCommand.SetBlendState(_alphaBlendState);
			RenderCommand.SetDepthStencilState(_depthStencilState);
			
			if (_editor.SceneViewportWindow.Visible)
			{
				_camera.Update(gameTime);

				_editorSceneRenderer.Scene = _activeScene;

				// Only use aspect ratio of editor-window, if game is not being rendered
				if (!_editor.GameViewportWindow.Visible)
					_activeScene.SetViewportSize((uint32)_editor.SceneViewportWindow.ViewportSize.X, (uint32)_editor.SceneViewportWindow.ViewportSize.Y);
				
				_editorSceneRenderer.SetViewportSize((uint32)_editor.SceneViewportWindow.ViewportSize.X, (uint32)_editor.SceneViewportWindow.ViewportSize.Y);

				RenderCommand.Clear(_editorViewportTarget, .Color | .Depth, .(0.2f, 0.2f, 0.2f), 1.0f, 0);
				_editorSceneRenderer.RenderEditor(gameTime, _camera, _editorViewportTarget, scope => DebugDraw3D, scope => DebugDraw2D);
			}

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
				float3 worldPos = transform.Translation;

				return Matrix.Translation(worldPos) * billboard;
			}

			float CalculateAlpha(float3 pos)
			{
				return Math.Clamp(1.5f - distance(_editor.CurrentCamera.Position, pos) / 50, 0, 1);
			}

			for (var (entity, transform, camera) in _activeScene.GetEntities<TransformComponent, CameraComponent>())
			{
				if (_editor.EntityHierarchyWindow.SelectedEntities.Contains(.(entity, _activeScene)))
				{
					DebugRenderer.DrawViewFrustum(transform.WorldTransform, camera.Camera.Projection, .White);
				}
				
				Matrix world = Billboard(transform.WorldTransform);
				
				float alpha = CalculateAlpha(transform.WorldTransform.Translation);
				Renderer2D.DrawQuad(world, _editorIcons.Camera, ColorRGBA(alpha, alpha, alpha, alpha), .(0, 0, 1, 1), entity.Index);
				//Renderer2D.DrawQuad(world, _iconCamera, .White, .(0, 0, 1, 1), entity.Index);
			}

			for (var (entity, transform, light) in _activeScene.GetEntities<TransformComponent, LightComponent>())
			{
				if (_editor.EntityHierarchyWindow.SelectedEntities.Contains(.(entity, _activeScene)))
				{
					Renderer.DrawRay(.Zero, .(0, 0, 20), ColorRGBA(light.SceneLight.Color, 1.0f), transform.WorldTransform);

					for (float angle = 0; angle < MathHelper.TwoPi; angle += MathHelper.TwoPi / 5.0f)
					{
						float2 pos = MathHelper.CirclePoint(angle, 0.5f);

						Renderer.DrawRay(.(pos, 0), .(pos, 20), .White, transform.WorldTransform);
					}
				}

				Matrix world = Billboard(transform.WorldTransform);
				
				float alpha = CalculateAlpha(transform.WorldTransform.Translation);
				Renderer2D.DrawQuad(world, _editorIcons.DirectionalLight, ColorRGBA(light.SceneLight.Color.R * alpha, light.SceneLight.Color.G * alpha, light.SceneLight.Color.B * alpha, alpha), .(0, 0, 1, 1), entity.Index);
			}
			
			for (var (entity, transform, collider) in _activeScene.GetEntities<TransformComponent, BoxCollider2DComponent>())
			{
				Renderer2D.DrawRect(transform.WorldTransform * Matrix.Translation(collider.Offset.X, collider.Offset.Y, 0) * Matrix.Scaling(collider.Size.X * 2, collider.Size.Y * 2, 0));
			}

			for (var (entity, transform, collider) in _activeScene.GetEntities<TransformComponent, CircleCollider2DComponent>())
			{
				Renderer2D.DrawCircle(transform.WorldTransform * Matrix.Translation(collider.Offset.X, collider.Offset.Y, 0) * Matrix.Scaling(collider.Radius * 2), (Texture2D)null, ColorRGBA(0f, 1f, 0f), 0.01f);
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
			// TODO: make window
			//Input.ImGuiDebugDraw();

			//viewer.ViewTexture(Renderer.[Friend]_gBuffer.Target);

			ImGui.Viewport* viewport = ImGui.GetMainViewport();
			ImGui.DockSpaceOverViewport(viewport);

			DrawMainMenuBar();

			_editor.SceneViewportWindow.RenderTarget = _editorViewportTarget;
			_editor.GameViewportWindow.RenderTarget = _gameViewportTarget;

			_editor.Update();

			_settingsWindow.Show();

			UI_Toolbar();

			return false;
		}

		private void UI_Toolbar()
		{
			ImGui.PushStyleVar(.WindowPadding, ImGui.Vec2(0, 2));
			ImGui.PushStyleVar(.ItemInnerSpacing, ImGui.Vec2(0, 0));
			ImGui.PushStyleColor(.Button, ImGui.Vec4(0, 0, 0, 0));

			let colors = ImGui.GetStyle().Colors;

			ImGui.Vec4 hoveredColor = colors[(int)ImGui.Col.ButtonHovered];
			hoveredColor.w = 0.5f;
			
			ImGui.Vec4 activeColor = colors[(int)ImGui.Col.ButtonActive];
			activeColor.w = 0.5f;

			ImGui.PushStyleColor(.ButtonHovered, hoveredColor);
			ImGui.PushStyleColor(.ButtonActive, activeColor);

			ImGui.Begin("##toolbar", null, .NoDecoration | .NoScrollbar | .NoScrollWithMouse);

			float padding = 2.0f;

			float size = ImGui.GetWindowHeight() - 2 * padding;

			float centerX = ImGui.GetContentRegionMax().x / 2;


			if (_sceneState == .Edit)
			EditorButtons:
			{
				// Display the buttons for edit state

				float totalWidth = size * 3 + padding * 4;

				ImGui.SameLine();
				ImGui.SetCursorPosX(centerX - totalWidth / 2);

				if (ImGui.ImageButton(_editorIcons.Play, .(size, size), .Zero, .Ones, 0))
					OnScenePlay();

				ImGui.AttachTooltip("Play the game.");
				
				ImGui.SameLine();

				ImGui.PushID(1);

				if (ImGui.ImageButton(_editorIcons.Simulate, .(size, size), .Zero, .Ones, 0))
					OnSceneSimulate();
				
				ImGui.PopID();

				ImGui.AttachTooltip("Enter simulation mode.\nThis only runs the physics engine.");

				if (_isPaused)
				{
					ImGui.PushStyleColor(.Button, *ImGui.GetStyleColorVec4(.ButtonActive));
					
					defer:EditorButtons { ImGui.PopStyleColor(); }
				}
				
				ImGui.PushID(2);

				//ImGui.SameLine(penX += size + 2 * padding);
				ImGui.SameLine();

				if (ImGui.ImageButton(_editorIcons.Pause, .(size, size), .Zero, .Ones, 0))
					_isPaused = !_isPaused;
				
				ImGui.PopID();

				ImGui.AttachTooltip("If enabled the game or simulation will be started in paused state.");

			}
			else
			{
				// Display the buttons for play/simulation state

				ImGui.SameLine();
				ImGui.SetCursorPosX(centerX - size - padding);

				SubTexture2D pauseButtonIcon = _isPaused ? _editorIcons.Play : _editorIcons.Pause;

				if (ImGui.ImageButton(pauseButtonIcon, .(size, size), .Zero, .Ones, 0))
				{
					if (_isPaused)
						OnSceneResume();
					else
						OnScenePause();
				}

				ImGui.AttachTooltip(_isPaused ? "Resume" : "Pause");
				
				ImGui.SameLine();
				ImGui.PushID(1);

				if (ImGui.ImageButton(_editorIcons.Stop, .(size, size), .Zero, .Ones, 0))
					OnSceneStop();

				ImGui.PopID();

				ImGui.AttachTooltip("Stop");
			}

			ImGui.End();

			ImGui.PopStyleColor(3);
			ImGui.PopStyleVar(2);
		}

		private void OnScenePlay()
		{
			_editor.SceneViewportWindow.EditorMode = false;
			_sceneState = .Play;

			using (Scene runtimeScene = new Scene())
			{
				_editorScene.CopyTo(runtimeScene);

				runtimeScene.OnRuntimeStart();

				SetReference!(_activeScene, runtimeScene);
			}

			_editor.CurrentScene = _activeScene;
		}

		private void OnSceneSimulate()
		{
			_editor.SceneViewportWindow.EditorMode = false;
			_sceneState = .Simulate;

			using (Scene simulationScene = new Scene())
			{
				_editorScene.CopyTo(simulationScene);

				simulationScene.OnSimulationStart();

				SetReference!(_activeScene, simulationScene);
			}

			_editor.CurrentScene = _activeScene;
		}

		private void OnScenePause()
		{
			_isPaused = true;
		}
		
		private void OnSceneResume()
		{
			_isPaused = false;
		}

		private void OnSceneStop()
		{
			if (_sceneState == .Play)
				_activeScene.OnRuntimeStop();
			else if (_sceneState == .Simulate)
				_activeScene.OnSimulationStop();

			SetReference!(_activeScene, _editorScene);

			_editor.SceneViewportWindow.EditorMode = true;
			_sceneState = .Edit;

			_editor.CurrentScene = _activeScene;
			
			_isPaused = false;

			if (_activeScene != null)
			{
				/*
				 * Update the viewport size because if the game windows size changed in
				 * "Game"-mode the updated aspect-rations will reset once we go back
				 * into "Editor"-mode (because Game-Mode works on a copy of the scene).
				 */
				GameViewportSizeChanged(null, _editor.GameViewportWindow.ViewportSize);
			}
		}

		/// Creates a new scene.
		private void NewScene()
		{
			OnSceneStop();

			SceneFilePath = null;

			using (Scene newScene = new Scene())
			{
				_camera.Position = .(-1.5f, 1.5f, -2.5f);
				_camera.RotationEuler = .(MathHelper.ToRadians(25), MathHelper.ToRadians(35), 0);
	
				// Create a default camera
				{
					let cameraEntity = newScene.CreateEntity("Camera");
					let transform = cameraEntity.Transform;
					transform.Position = float3(0, 2, -5);
					transform.RotationEuler = float3(0, MathHelper.ToRadians(25), 0);
					
					let camera = cameraEntity.AddComponent<CameraComponent>();
					camera.Primary = true;
					camera.Camera.ProjectionType = .InfinitePerspective;
					camera.Camera.PerspectiveFovY = MathHelper.ToRadians(75);
					camera.Camera.PerspectiveNearPlane = 0.1f;
				}
	
				// Create a default light source
				{
					let lightEntity = newScene.CreateEntity("Light");
					let transform = lightEntity.Transform;
					transform.Position = .(-3, 4, -1.5f);
					transform.RotationEuler = .(MathHelper.ToRadians(20), MathHelper.ToRadians(75), MathHelper.ToRadians(20));
	
					let light = lightEntity.AddComponent<LightComponent>();
					light.SceneLight.Illuminance = 10.0f;
					light.SceneLight.Color = .(1.0f, 0.95f, 0.8f);
				}
	
				SetReference!(_editorScene, newScene);
				_editor.CurrentScene = _editorScene;
				SetReference!(_activeScene, _editorScene);
			}
		}
		
		/// Saves the scene in the file that is was loaded from or saved to last. If there is no such path (i.e. it is a new scene) the save file dialog will open.
		private void SaveScene()
		{
			if (SceneFilePath.IsWhiteSpace)
			{
				SaveSceneAs();
				return;
			}
			
			SceneSerializer serializer = scope .(_editorScene);
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
					LoadSceneFile(ofd.FileNames[0]);
				}
			}
		}

		/// Loads the given scene file.
		private void LoadSceneFile(StringView filename)
		{
			OnSceneStop();

			SceneFilePath = scope String(filename);

			using (Scene newScene = new Scene())
			{
				SceneSerializer serializer = scope .(newScene);
				let result = serializer.Deserialize(SceneFilePath);

				// Make sure we actually loaded something!
				if (result case .Ok)
				{
					SetReference!(_editorScene, newScene);
					_editor.CurrentScene = _editorScene;
					SetReference!(_activeScene, _editorScene);
				}
				else
				{
					Log.EngineLogger.Error("Failed to load scene file.");
				}
			}
		}

		private void DrawOpenRecentProjectMenu()
		{
			int i = 0;

			for (let (name, path) in _recentProjectPaths)
			{
				i++;
				if (i >= 10)
					break;

				if (ImGui.MenuItem(scope $"{i}: {name} ({path})"))
				{
					LoadSceneFile(path);
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

				if (ImGui.MenuItem("Save as...", "Ctrl+Shift+S"))
					SaveSceneAs();

				if (ImGui.MenuItem("Open...", "Ctrl+O"))
					OpenScene();
				
				if (ImGui.BeginMenu("Open Recent"))
				{
					DrawOpenRecentProjectMenu();

					ImGui.EndMenu();
				}

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
				if(ImGui.MenuItem(ComponentEditWindow.s_WindowTitle))
					_editor.ComponentEditWindow.Open = true;

				if(ImGui.MenuItem(ContentBrowserWindow.s_WindowTitle))
					_editor.ComponentEditWindow.Open = true;
				
				if(ImGui.MenuItem(EditorViewportWindow.s_WindowTitle))
					_editor.SceneViewportWindow.Open = true;

				if(ImGui.MenuItem(EntityHierarchyWindow.s_WindowTitle))
					_editor.EntityHierarchyWindow.Open = true;

				if(ImGui.MenuItem(GameViewportWindow.s_WindowTitle))
					_editor.GameViewportWindow.Open = true;

				if(ImGui.MenuItem(PropertiesWindow.s_WindowTitle))
					_editor.PropertiesWindow.Open = true;

				if(ImGui.MenuItem(AssetViewer.s_WindowTitle))
					_editor.AssetViewer.Open = true;

				ImGui.EndMenu();
			}
			
			if(ImGui.BeginMenu("Tools", true))
			{
				if(ImGui.MenuItem("Reload Scripts"))
					ScriptEngine.ReloadAssemblies();

				ImGui.EndMenu();
			}


			ImGui.EndMainMenuBar();
		}

		private bool OnWindowResize(WindowResizeEvent e)
		{
			return false;
		}

		private void EditorViewportSizeChanged(Object sender, float2 viewportSize)
		{
			if(viewportSize.X <= 0 || viewportSize.Y <= 0)
				return;

			uint32 sizeX = (uint32)viewportSize.X;
			uint32 sizeY = (uint32)viewportSize.Y;

			_editorViewportTarget.Resize(sizeX, sizeY);
			_cameraTarget.Resize(sizeX, sizeY);

			_camera.OnViewportResize(sizeX, sizeY);

			_activeScene.SetViewportSize(sizeX, sizeY);
		}
		
		private void GameViewportSizeChanged(Object sender, float2 viewportSize)
		{
			if(viewportSize.X <= 0 || viewportSize.Y <= 0)
				return;

			uint32 sizeX = (uint32)viewportSize.X;
			uint32 sizeY = (uint32)viewportSize.Y;

			_gameViewportTarget.Resize(sizeX, sizeY);

			_activeScene.SetViewportSize(sizeX, sizeY);
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
