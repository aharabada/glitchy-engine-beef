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
using GlitchyEngine.Serialization;
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

		ProjectUserSettings _projectUserSettings;

		EditorCamera _camera ~ _.Dispose();

		EditorIcons _editorIcons ~ _.ReleaseRef();

		EditorContentManager _contentManager;

		SceneState _sceneState = .Edit;
		bool _isPaused = false;
		bool _singleStep = false;

		private float _fixedTimestep = 1.0f / 60.0f;
		
		append List<(String Name, String Path)> _recentScenePaths = .() ~ {
				for (var item in _)
				{
					delete item.Name;
					delete item.Path;
				}
			};
		
		private GameTime _simulationGameTime = new .() ~ delete _;
		
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

		private Project _currentProject ~ delete _;

		public Project CurrentProject => _currentProject;

		public bool IsProjectLoaded => _currentProject != null;
		
		/// Returns whether or not the current scene can be saved.
		public bool CanSaveScene => _sceneState == .Edit;

		private AssetThumbnailManager _thumbnailManager ~ delete _;

#if GE_EDITOR_IMGUI_DEMO
		private bool _showImguiDemoWindow;
#endif

		[AllowAppend]
		public this(String[] args, EditorContentManager contentManager) : base("Editor")
		{
			Application.Get().Window.IsVSync = true;

			ScriptEngine.ApplicationInfo.IsEditor = true;

			_contentManager = contentManager;

			InitGraphics();

			_gameSceneRenderer = new SceneRenderer();
			_editorSceneRenderer = new SceneRenderer();

			_camera = EditorCamera(float3(-3f, 3f, -3f), Quaternion.FromEulerAngles(MathHelper.ToRadians(40), MathHelper.ToRadians(25), 0), MathHelper.ToRadians(75), 0.1f, 1);
			_camera.RenderTarget = _cameraTarget;

			_thumbnailManager = new AssetThumbnailManager(_editorIcons);

			InitEditor();

			RegisterAssetCreators();

			if (args.Count >= 1)
			{
				Result<void> result = LoadAndOpenProject(args[0]);

				if (result == .Err)
					Log.EngineLogger.Error($"Failed to open project \"{args[0]}\".");
			}

			// Create a new scene if no scene is loaded
			if (_activeScene == null)
				CreateAndOpenNewScene();
		}

		public ~this()
		{
			CloseCurrentProject();
		}

		private void RegisterAssetCreators()
		{
			Editor.Instance.ContentBrowserWindow.RegisterAssetCreator(new AssetCreator("Folder", "New Folder", "", new (path) =>
				{
					if (Directory.CreateDirectory(path) case .Err(let error))
					{
						Log.ClientLogger.Error($"Directory \"{path}\" could not be created ({error}).");
					}
				}, _editorIcons.Folder));

			Editor.Instance.ContentBrowserWindow.InsertAssetCreatorSeparator();

			Editor.Instance.ContentBrowserWindow.RegisterAssetCreator(new AssetCreator("Scene", "New Scene", ".scene", new (path) =>
				{
					using (Scene newScene = CreateNewScene())
					{
						SaveScene(newScene, path);
					}
				}, _editorIcons.File_Scene));

			Editor.Instance.ContentBrowserWindow.RegisterAssetCreator(new AssetCreator("Material", "New Material", ".mat", new (path) =>
				{
					using (Material newMaterial = new Material())
					{
						_contentManager.SaveAssetToFile(newMaterial, path);
					}
				}, _editorIcons.File_Material));
			
			Editor.Instance.ContentBrowserWindow.RegisterAssetCreator(new AssetCreator("Script", "New Entity", ".cs", new (path) =>
				{
					String templatePath = scope .();
					Directory.GetCurrentDirectory(templatePath);
					Path.Combine(templatePath, "Resources/Templates/ScriptTemplate.cs");

					String scriptContent = scope .();

					if (File.ReadAllText(templatePath, scriptContent, true) case .Err(let error))
					{
						Log.EngineLogger.Error($"Failed to read template file from \"{templatePath}\". Error: {error}");
						return;
					}

					scriptContent.Replace("[ProjectName]", CurrentProject.Name);

					String fileName = scope .();
					Path.GetFileName(path, fileName);

					Log.EngineLogger.AssertDebug(fileName.EndsWith(".cs"));

					if (fileName.EndsWith(".cs"))
						fileName.RemoveFromEnd(3);

					String pascalFileName = scope .(fileName.Length);
					ToPascalCase(fileName, pascalFileName);
					String cSharpClassName = scope .(pascalFileName.Length);
					ToCSharpName(pascalFileName, cSharpClassName);

					scriptContent.Replace("[EntityName]", cSharpClassName);

					if (File.WriteAllText(path, scriptContent, false) case .Err)
					{
						Log.EngineLogger.Error($"Failed to save script file to \"{path}\".");
						return;
					}

					// Add to .csproj
					String assetRelativePath = scope .();
					Path.GetRelativePath(path, _currentProject.WorkspacePath, assetRelativePath);

					String projectPath = scope .();
					Editor.Instance.CurrentProject.PathInProject(projectPath, scope $"{Editor.Instance.CurrentProject.Name}.csproj");

					String projectFile = scope .();
					let loadProjectResult = File.ReadAllText(projectPath, projectFile, true);

					if (loadProjectResult case .Err(let err))
					{
						Log.EngineLogger.Error($"Failed to open project file ({err}). Please add the file to the project manually.");
					}

					const String scriptFilesMarker = "<!-- Script Files -->";

					int index = projectFile.IndexOf(scriptFilesMarker);
					int lineEndIndex = projectFile.IndexOf('\n', index);
					projectFile.Insert(lineEndIndex + 1, scope $"    <Compile Include=\"{assetRelativePath}\" />\n");
					
					let saveProjectResult = File.WriteAllText(projectPath, projectFile);

					if (saveProjectResult case .Err(let err))
					{
						Log.EngineLogger.Error($"Failed to edit project file ({err}). Please add the file to the project manually.");
					}
				}, _editorIcons.File_CSharpScript));
		}

		private void ToCSharpName(String input, String output)
		{
			for (char32 c in input.DecodedChars)
			{
				if (c.IsLetterOrDigit || c == '_' || c == '@')
				{
					output.Append(c);
				}
			}

			let decode = System.Text.UTF8.Decode(output.Ptr, output.Length);
			
			// Make sure the name starts with a letter or _ or @
			if (!(decode.c.IsLetter || decode.c == '_' || decode.c == '@'))
			{
				output.Insert(0, '@');
			}
		}

		private void ToPascalCase(String input, String output)
		{
			bool newWord = true;

			for (char32 c in input.DecodedChars)
			{
				if (c.IsLetter)
				{
					if (newWord)
					{
						output.Append(c.ToUpper);
						newWord = false;
					}
					else
					{
						output.Append(c);
					}
				}
				else
				{
					newWord = true;

					if (c.IsWhiteSpace || c == '_')
					{
						continue;
					}
					else
					{
						output.Append(c);
					}
				}
			}
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

			_editorIcons = new EditorIcons("Resources/Textures/EditorIcons.dds", .(64, 64));
			_editorIcons.SamplerState = SamplerStateManager.AnisotropicClamp;

			ContentBrowserWindow.s_FolderTexture = _editorIcons.Folder;
			ContentBrowserWindow.s_FileTexture = _editorIcons.File;

			LogWindow.s_ErrorIcon = _editorIcons.Error;
			LogWindow.s_WarningIcon = _editorIcons.Warning;
			LogWindow.s_InfoIcon = _editorIcons.Info;
			LogWindow.s_TraceIcon = _editorIcons.Trace;
		}

		private void InitEditor()
		{
			_editor = new Editor(_editorScene, _contentManager, _thumbnailManager);
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

			if (IsProjectLoaded)
				UpdateScene(gameTime);
		}

		private void UpdateScene(GameTime gameTime)
		{
			_editor.CurrentScene = _activeScene;

			Scene.UpdateMode updateMode;

			switch (_sceneState)
			{
			case .Edit:
				updateMode = .Scripts | .EditMode;
			case .Play:
				updateMode = .Scripts | .Physics;
			case .Simulate:
				updateMode = .Physics;
			}

			// Don't step if we are in in the simulation/game but paused and don't single step
			if (_sceneState != .Edit && _isPaused && !_singleStep)
				updateMode = .None;

			/*
			 * If we are in edit mode we use the "official" gametime.
			 * However in play or simulation mode we use a simulation game time
			 * which is decoupled from the actual time. This allows us to manipulate
			 * the simulation speed without potentially messing with the rest of the editor.
			 */
			GameTime gt = null;

			if (updateMode.HasFlag(.EditMode))
			{
				gt = gameTime;
			}
			else
			{
				gt = _simulationGameTime;
				
				if (_singleStep)
				{
					_singleStep = false;
					_simulationGameTime.ManualStepFrame(_fixedTimestep);
				}
				else
				{
					_simulationGameTime.ManualStepFrame(gameTime.DeltaTime);
				}
			}

			_activeScene.Update(gt, updateMode);

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
				if (_editor.EntityHierarchyWindow.IsEntitySelected(.(entity, _activeScene)))
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
				if (_editor.EntityHierarchyWindow.IsEntitySelected(.(entity, _activeScene)))
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
				Renderer2D.DrawRect(transform.WorldTransform * Matrix.Translation(collider.Offset.X, collider.Offset.Y, 0) * Matrix.Scaling(collider.Size.X * 2, collider.Size.Y * 2, 0), .Green, entity.Index);
			}

			for (var (entity, transform, collider) in _activeScene.GetEntities<TransformComponent, CircleCollider2DComponent>())
			{
				Renderer2D.DrawCircle(transform.WorldTransform * Matrix.Translation(collider.Offset.X, collider.Offset.Y, 0) * Matrix.Scaling(collider.Radius * 2), (Texture2D)null, ColorRGBA(0f, 1f, 0f), 0.01f, .(0, 0, 1, 1), entity.Index);
			}

			for (var (entity, transform, collider) in _activeScene.GetEntities<TransformComponent, PolygonCollider2DComponent>())
			{
				Matrix colliderTransform = transform.WorldTransform * Matrix.Translation(collider.Offset.X, collider.Offset.Y, 0);

				float3 firstPosition = (colliderTransform * float4(collider.Vertices[0], 0, 1)).XYZ;
				float3 lastPosition = firstPosition;

				for (int i = 1; i < collider.VertexCount; i++)
				{
					float3 position = (colliderTransform * float4(collider.Vertices[i], 0, 1)).XYZ;

					Renderer2D.DrawLine(lastPosition, position, .Green, entity.Index);

					lastPosition = position;
				}

				Renderer2D.DrawLine(lastPosition, firstPosition, .Green, entity.Index);
			}
		}
		
		/// Updates the title of the window.
		private void UpdateWindowTitle()
		{
			String title = scope String("Glitchy Engine");

			if (_currentProject != null)
			{
				title.AppendF($" - {_currentProject.Name}");
			}

			if (_editorScene != null)
			{
				title.AppendF($" | {_editorScene.Name}");
			}

			Application.Instance.Window.Title = title;
		}

#region Project Management

		/// Creates a new Project and opens it.
		/// @param workspaceDirectory The workspace directory of the new project (The directory that all files will be in).
		/// @param projectName Name of the new project.
		/// @remarks If the creation fails at any point the entire directory will be deleted.
		private Result<void> CreateNewProject(StringView workspaceDirectory, StringView projectName)
		{
			if (Directory.CreateDirectory(workspaceDirectory) case .Err(let error))
			{
				Log.ClientLogger.Error($"Failed to create directory \"{workspaceDirectory}\". ({error})");
				return .Err;
			}

			if (!Directory.IsEmpty(workspaceDirectory))
			{
				Log.ClientLogger.Error($"Target directory is not empty.");
				return .Err;
			}
			
			String templatePath = scope .();
			Directory.GetCurrentDirectory(templatePath);
			Path.Combine(templatePath, "Resources/ProjectTemplate");

			Result<Project> newProjectResult = Project.CreateNewFromTemplate(workspaceDirectory, projectName, templatePath);

			// If the project couldn't be created or initialization failed, we delete the workspace directory.
			if (newProjectResult == .Err)
			{
				if (Directory.DelTree(workspaceDirectory) case .Err(let error))
				{
					Log.EngineLogger.Error($"Failed to delete workspace ({workspaceDirectory}).");
				}

				return .Err;
			}
			
			if (OpenProject(newProjectResult.Get()) case .Err)
			{
				Log.ClientLogger.Error($"Failed to open newly created project.");
				return .Err;
			}

			return .Ok;
		}

		/// If set to true, the popup for creating a new project will be shown.
		private bool _openCreateProjectModal;

		private void ShowCreateNewProjectModal()
		{
			static char8[128] projectNameBuffer = .();
			static char8[256] projectDirectoryBuffer = .();

			if (_openCreateProjectModal)
			{
				ImGui.OpenPopup("Create new Project");
				_openCreateProjectModal = false;

				projectNameBuffer = .();
			}

			// Always center this window when appearing
			var center = ImGui.GetMainViewport().GetCenter();
			ImGui.SetNextWindowPos(center, .Appearing, .(0.5f, 0.5f));

			if (ImGui.BeginPopupModal("Create new Project", null, .AlwaysAutoResize))
			{
				ImGui.TextUnformatted("Project Name:");
				ImGui.InputText("##projectName", &projectNameBuffer, projectNameBuffer.Count - 1);

				ImGui.NewLine();

				ImGui.TextUnformatted("Directory:");
				ImGui.InputText("##directory", &projectDirectoryBuffer, projectDirectoryBuffer.Count - 1);
				ImGui.SameLine();

				if (ImGui.Button("..."))
				{
					FolderBrowserDialog folderDialog = scope FolderBrowserDialog();
					Result<DialogResult> result = folderDialog.ShowDialog();

					if (result case .Ok(let dialogResult) && dialogResult case .OK)
					{
						folderDialog.SelectedPath.CopyTo(projectDirectoryBuffer);
					}
				}

				StringView projectName = StringView(&projectNameBuffer);
				StringView directory = StringView(&projectDirectoryBuffer);

				String target = scope String();
				Path.Combine(target, directory, projectName);
				
				ImGui.NewLine();

				ImGui.Text($"The Project will be in:\n{target}");

				if (Directory.Exists(target))
				{
					ImGui.TextColored(.(1, 0, 0, 1), "The directory is not empty!");
				}

				ImGui.NewLine();

				ImGui.BeginDisabled(directory.IsWhiteSpace || projectName.IsWhiteSpace);

				if (ImGui.Button("Create"))
				{
					Result<void> result = CreateNewProject(target, projectName);

					if (result case .Ok)
						ImGui.CloseCurrentPopup();
				}

				ImGui.EndDisabled();

				ImGui.SameLine();

				if (ImGui.Button("Cancel"))
				{
					ImGui.CloseCurrentPopup();
				}

				ImGui.EndPopup();
			}
		}

		private void ShowOpenProjectDialog()
		{
			FolderBrowserDialog folderDialog = scope FolderBrowserDialog();
			Result<DialogResult> result = folderDialog.ShowDialog();

			if (result case .Ok(let dialogResult) && dialogResult case .OK)
			{
				LoadAndOpenProject(folderDialog.SelectedPath);
			}
		}

		private void CloseCurrentProject()
		{
			CloseCurrentScene();

			SetEditorScene(null);
	
			_currentProject?.SaveUserSettings();

			// TODO: Do actual work here!
			delete _currentProject;
			_currentProject = null;
		}

		private Result<void> LoadAndOpenProject(StringView workspacePath)
		{
			Project openedProject = Project.Load(workspacePath);

			if (OpenProject(openedProject) case .Err)
			{
				Log.ClientLogger.Error($"Failed to open project {workspacePath}.");
				return .Err;
			}

			return .Ok;
		}

		/// Opens the given project and makes it the current project.
		private Result<void> OpenProject(Project project)
		{
			if (project == null)
				return .Err;
			
			CloseCurrentProject();

			_currentProject = project;

			_editor.CurrentProject = _currentProject;

			String appAssemblyPath = scope String();
			_contentManager.SetAssetDirectory(_currentProject.AssetsFolder);
			_contentManager.SetAssetCacheDirectory(_currentProject.GetScopedPath!(".cache"));

			_currentProject.PathInProject(appAssemblyPath, scope $"bin/{_currentProject.Name}.dll");

			ScriptEngine.SetAppAssemblyPath(appAssemblyPath);

			if (!_currentProject.UserSettings.LastOpenedScene.IsWhiteSpace)
			{
				String lastSceneFile = _currentProject.GetScopedPath!(_currentProject.UserSettings.LastOpenedScene);

				if (File.Exists(lastSceneFile))
					LoadSceneFile(lastSceneFile);
				else
					CreateAndOpenNewScene();
			}
			else
				CreateAndOpenNewScene();

			UpdateWindowTitle();

			if (Directory.Exists(project.WorkspacePath))
			{
				Application.Instance.Settings.EditorSettings.LastOpenedProject = project.WorkspacePath;
				Application.Instance.Settings.Save();
			}

			return .Ok;
		}

#endregion Project Management

#region Scene Management

		/// Focuses the Play window, so that its tab will be shown.
		private void SwitchToPlayWindow()
		{
			let window = ImGui.FindWindowByName(GameViewportWindow.s_WindowTitle);
			ImGui.FocusWindow(window);
		}

		/// Focuses the Editor window, so that its tab will be shown.
		private void SwitchToEditorWindow()
		{
			let window = ImGui.FindWindowByName(EditorViewportWindow.s_WindowTitle);
			ImGui.FocusWindow(window);
		}
		
		append ScriptInstanceSerializer _scriptSerializer = .();

		/// Starts the play mode for the current scene
		private void OnScenePlay()
		{
			Log.EngineLogger.AssertDebug(_scriptSerializer.SerializedObjectCount == 0, "Somehow some entities are serialized.");

			_scriptSerializer.SerializeScriptInstances();
			
			_editor.SceneViewportWindow.EditorMode = false;
			_sceneState = .Play;

			using (Scene runtimeScene = new Scene())
			{
				_editorScene.CopyTo(runtimeScene, true);

				SetActiveScene(runtimeScene, startRuntime: true, startSimulation: true, newPlayMode: .Play);
				
				_scriptSerializer.DeserializeScriptInstances();
			}

			_editor.CurrentScene = _activeScene;

			if (Application.Instance.Settings.EditorSettings.SwitchToPlayerOnPlay)
				SwitchToPlayWindow();
		}

		enum PlayMode
		{
			Play,
			Editor,
			Simulation
		}

		/// Activates the given scene.
		/// @param scene The scene to be activated.
		/// @param startRuntime If set to true, the script runtime will be initialized for the given scene.
		/// @param startSimulation If set to true, the physics simulation will be initialized for the given scene.
		private void SetActiveScene(Scene scene, bool startRuntime, bool startSimulation, PlayMode? newPlayMode = null)
		{
			_activeScene?.Stop();

			if (newPlayMode != null)
			{
				switch (newPlayMode.Value)
				{
				case .Play:
					ScriptEngine.ApplicationInfo.IsInPlayMode = true;
				case .Editor:
					ScriptEngine.ApplicationInfo.IsInEditMode = true;
				case .Simulation:
					// No scripts in Simulation
					ScriptEngine.ApplicationInfo.IsInEditMode = false;
					ScriptEngine.ApplicationInfo.IsInPlayMode = false;
				}
			}

			if (scene != null)
			{
				scene.Start(startRuntime, startSimulation);
			}

			SetReference!(_activeScene, scene);
		}

		/// Starts the physics simulation mode for the current scene
		private void OnSceneSimulate()
		{
			_editor.SceneViewportWindow.EditorMode = false;
			_sceneState = .Simulate;

			using (Scene simulationScene = new Scene())
			{
				_editorScene.CopyTo(simulationScene, false);

				SetActiveScene(simulationScene, startRuntime: false, startSimulation: true, newPlayMode: .Simulation);
			}

			_editor.CurrentScene = _activeScene;
			
			if (Application.Instance.Settings.EditorSettings.SwitchToPlayerOnSimulate)
				SwitchToPlayWindow();
		}

		/// Pauses the scene
		private void OnScenePause()
		{
			_isPaused = true;
			
			if (Application.Instance.Settings.EditorSettings.SwitchToEditorOnPause)
				SwitchToEditorWindow();
		}

		/// Resumes the simulation / game
		private void OnSceneResume()
		{
			_isPaused = false;
			
			if (Application.Instance.Settings.EditorSettings.SwitchToPlayerOnResume)
				SwitchToPlayWindow();
		}

		/// Requests execution of a single simulation / game tick
		private void DoSingleStep()
		{
			_singleStep = true;
		}

		/// Stops the simulation or game and returns to edit mode.
		private void OnSceneStop()
		{
			SetActiveScene(_editorScene, startRuntime: true, startSimulation: false, newPlayMode: .Editor);

			// TODO: _editorScene.DeserializeScripts(scriptData);

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
			
			if (Application.Instance.Settings.EditorSettings.SwitchToEditorOnStop)
				SwitchToEditorWindow();

			// Reconstruct state before play
			_scriptSerializer.DeserializeScriptInstances();
			_scriptSerializer.Clear();
		}

		/// Stops the scene and cleans up the subsystems to allow loading another scene.
		private void CloseCurrentScene()
		{
			// Clear serialized data, so that we don't waste time deserializing it.
			_scriptSerializer.Clear();
			OnSceneStop();
		}

		/// Creates a new scene and openes it.
		private void CreateAndOpenNewScene()
		{
			CloseCurrentScene();

			SceneFilePath = null;

			using (Scene newScene = CreateNewScene())
			{
				_camera.Position = .(-1.5f, 1.5f, -2.5f);
				_camera.RotationEuler = .(MathHelper.ToRadians(25), MathHelper.ToRadians(35), 0);

				SetEditorScene(newScene);
			}
		}

		/// Sets the current editor scene
		private void SetEditorScene(Scene scene, ScriptInstanceSerializer serializedObjects = null)
		{
			_editorScene?.Stop();

			SetReference!(_editorScene, scene);
			_editor.CurrentScene = _editorScene;
			SetReference!(_activeScene, _editorScene);

			if (_editorScene != null)
			{
				_editorScene.Start(startRuntime: true, startSimulation: false);

				if (serializedObjects != null)
				{
					// Reconstruct state
					serializedObjects.DeserializeScriptInstances();
				}
			}

			UpdateWindowTitle();
		}

		/// Creates a new default scene.
		private static Scene CreateNewScene()
		{
			Scene newScene = new Scene();

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

			return newScene;
		}
		
		/// Saves the scene in the file that is was loaded from or saved to last. If there is no such path (i.e. it is a new scene) the save file dialog will open.
		private void SaveCurrentScene()
		{
			if (!CanSaveScene)
			{
				Log.ClientLogger.Error("Scene can't be saved while playing the game!");
				return;
			}

			if (SceneFilePath.IsWhiteSpace)
			{
				SaveCurrentSceneAs();
			}
			else
			{
				SaveScene(_editorScene, SceneFilePath);
			}

			// Note: We only update the last opened scene if the CURRENT scene is saved, NOT when ANY scene is saved.
			String relativePath = scope .();
			Path.GetRelativePath(SceneFilePath, _currentProject.WorkspacePath, relativePath);
			_currentProject.UserSettings.LastOpenedScene = relativePath;
		}

		/// Saves the given scene with the specified file name.
		private static void SaveScene(Scene scene, StringView fileName)
		{
			SceneSerializer serializer = scope .(scene);
			serializer.Serialize(fileName);
		}
		
		/// Opens a save file dialog and saves the scene at the user specified location.
		private void SaveCurrentSceneAs()
		{
			if (!CanSaveScene)
			{
				Log.ClientLogger.Error("Scene can't be saved while playing the game!");
				return;
			}

			SaveFileDialog sfd = scope .();
			sfd.InitialDirectory = _currentProject.AssetsFolder;
			sfd.SetFilter("scene file (*.scene)|*.scene");

			if (sfd.ShowDialog() case .Ok(let result) && result == .OK)
			{
				SceneFilePath = sfd.FileNames[0];
				SaveCurrentScene();
			}
		}
		
		/// Opens a open file dialog and load the scene selected by the user specified.
		private void OpenScene()
		{
			OpenFileDialog ofd = scope .();
			ofd.InitialDirectory = _currentProject.AssetsFolder;
			ofd.SetFilter("scene file (*.scene)|*.scene");

			if (ofd.ShowDialog() case .Ok(let result) && result == .OK)
			{
				LoadSceneFile(ofd.FileNames[0]);
			}
		}

		/// Loads the given scene file and opens it as the current scene.
		private void LoadSceneFile(StringView filename)
		{
			CloseCurrentScene();

			SceneFilePath = scope String(filename);

			using (Scene newScene = new Scene())
			{
				SceneSerializer serializer = scope .(newScene);
				let result = serializer.Deserialize(SceneFilePath);

				// Make sure we actually loaded something!
				if (result case .Ok)
				{
					SetEditorScene(newScene, serializer.ScriptSerializer);

					String relativePath = scope .();
					Path.GetRelativePath(filename, _currentProject.WorkspacePath, relativePath);
					_currentProject.UserSettings.LastOpenedScene = relativePath;
				}
				else
				{
					Log.ClientLogger.Error("Failed to load scene file.");
				}
			}
		}

#endregion Scene Management

#region ImGui
		
		private bool OnImGuiRender(ImGuiRenderEvent event)
		{
			ImGui.Viewport* viewport = ImGui.GetMainViewport();
			ImGui.DockSpaceOverViewport(viewport);

			DrawMainMenuBar();

#if GE_EDITOR_IMGUI_DEMO
			if (_showImguiDemoWindow)
			{
				ImGui.ShowDemoWindow();
			}
#endif

			_editor.SceneViewportWindow.RenderTarget = _editorViewportTarget;
			_editor.GameViewportWindow.RenderTarget = _gameViewportTarget;

			_editor.Update();

			_settingsWindow.Show();
			ShowCreateNewProjectModal();

			return false;
		}

		/// Shows the window with Play/Pause, etc. buttons
		private void ShowPlayControls()
		{
			ImGui.PushStyleVar(.ItemInnerSpacing, ImGui.Vec2(0, 0));
			ImGui.PushStyleColor(.Button, ImGui.Vec4(0, 0, 0, 0));

			let colors = ImGui.GetStyle().Colors;

			ImGui.Vec4 hoveredColor = colors[(int)ImGui.Col.ButtonHovered];
			hoveredColor.w = 0.5f;
			
			ImGui.Vec4 activeColor = colors[(int)ImGui.Col.ButtonActive];
			activeColor.w = 0.5f;

			ImGui.PushStyleColor(.ButtonHovered, hoveredColor);
			ImGui.PushStyleColor(.ButtonActive, activeColor);

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
				
				ImGui.PushID(0);

				if (ImGui.ImageButton("", _editorIcons.Play, .(size, size), .Zero, .Ones))
					OnScenePlay();
				
				ImGui.PopID();

				ImGui.AttachTooltip("Play the game.");
				
				ImGui.SameLine();

				ImGui.PushID(1);

				if (ImGui.ImageButton("", _editorIcons.Simulate, .(size, size), .Zero, .Ones))
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

				if (ImGui.ImageButton("", _editorIcons.Pause, .(size, size), .Zero, .Ones))
					_isPaused = !_isPaused;
				
				ImGui.PopID();

				ImGui.AttachTooltip("If enabled the game or simulation will be started in paused state.");

			}
			else
			{
				float totalWidth = size * 2 + padding * 2;

				if (_isPaused)
				{
					totalWidth = size * 3 + padding * 4;
				}

				ImGui.SameLine();
				ImGui.SetCursorPosX(centerX - totalWidth / 2.0f);

				SubTexture2D pauseButtonIcon = _isPaused ? _editorIcons.Play : _editorIcons.Pause;

				if (ImGui.ImageButton("PlayPause", pauseButtonIcon, .(size, size), .Zero, .Ones))
				{
					if (_isPaused)
						OnSceneResume();
					else
						OnScenePause();
				}

				ImGui.AttachTooltip(_isPaused ? "Resume" : "Pause");

				if (_isPaused)
				{
					ImGui.PushID(2);

					ImGui.SameLine();

					SubTexture2D singleStepButtonIcon = _editorIcons.SingleStep;

					if (ImGui.ImageButton("Step", singleStepButtonIcon, .(size, size), .Zero, .Ones))
					{
						DoSingleStep();
					}

					if (ImGui.BeginPopupContextItem())
					{
						if (ImGui.BeginTable("time_step_table", 2))
						{
							ImGui.TableNextRow();
							ImGui.TableNextColumn();

							ImGui.TextUnformatted("Time step:");

							ImGui.TableNextColumn();

							float itemWidth = ImGui.CalcTextSize("1000.000 FPS").x;

							ImGui.SetNextItemWidth(itemWidth);

							ImGui.DragFloat("##timestep", &_fixedTimestep, 0.001f, 0.001f, 1000.0f, "%.4fs");

							ImGui.TableNextRow();
							ImGui.TableNextColumn();

							float fps = 1.0f / _fixedTimestep;
							
							ImGui.TextUnformatted("Frame rate:");

							ImGui.TableNextColumn();

							ImGui.SetNextItemWidth(itemWidth);

							if (ImGui.DragFloat("##fps", &fps, 1.0f, 0.001f, 1000.0f, "%.3f FPS"))
							{
								_fixedTimestep = 1.0f / fps;
							}

							ImGui.EndTable();
						}

						ImGui.EndPopup();
					}

					ImGui.AttachTooltip("Step one Frame (Right-click to change time step)");

					ImGui.PopID();
				}

				ImGui.SameLine();
				ImGui.PushID(1);

				if (ImGui.ImageButton("Stop", _editorIcons.Stop, .(size, size), .Zero, .Ones))
					OnSceneStop();

				ImGui.PopID();

				ImGui.AttachTooltip("Stop");
			}

			ImGui.PopStyleColor(3);
			ImGui.PopStyleVar(1);
		}

		private void ShowOpenRecentSceneMenu()
		{
			if (_currentProject == null || _currentProject.UserSettings.RecentScenes == null)
				return;

			int i = 0;

			for (let scenePath in _currentProject.UserSettings.RecentScenes)
			{
				i++;

				String fullScenePath = _currentProject.GetScopedPath!(scenePath);

				if (!File.Exists(fullScenePath))
				{
					delete scenePath;
					@scenePath.Remove();
				}

				if (ImGui.MenuItem(scope $"{i}: {scenePath}"))
				{
					LoadSceneFile(fullScenePath);
				}
			}
		}

		private void ShowOpenRecentProjectMenu()
		{
			let recentProjects = Application.Instance.Settings.EditorSettings.RecentProjects;

			if (recentProjects == null)
				return;

			int i = 0;

			for (let workspacePath in recentProjects)
			{
				i++;

				if (!Directory.Exists(workspacePath))
				{
					delete workspacePath;
					@workspacePath.Remove();
					continue;
				}

				if (ImGui.MenuItem(scope $"{i}: {workspacePath}"))
				{
					LoadAndOpenProject(workspacePath);
				}
			}
		}

		private void DrawMainMenuBar()
		{
			ImGui.BeginMainMenuBar();

			if(ImGui.BeginMenu("File", true))
			{
				if (ImGui.MenuItem("New Scene", "Ctrl+N"))
					CreateAndOpenNewScene();
				
				ImGui.AttachTooltip("Creates a new (almost) empty scene.");

				if (ImGui.MenuItem("Open Scene...", "Ctrl+O"))
					OpenScene();
				
				ImGui.AttachTooltip("Opens an existing Scene.");

				if (ImGui.BeginMenu("Open recent Scene"))
				{
					ShowOpenRecentSceneMenu();

					ImGui.EndMenu();
				}

				ImGui.Separator();

				ImGui.BeginDisabled(!CanSaveScene);

				if (ImGui.MenuItem("Save Scene", "Ctrl+S"))
					SaveCurrentScene();
				
				ImGui.AttachTooltip("Saves the current scene.");

				if (ImGui.MenuItem("Save Scene as...", "Ctrl+Shift+S"))
					SaveCurrentSceneAs();
				
				ImGui.AttachTooltip("Saves the scene under the given file name.");

				ImGui.EndDisabled();

				ImGui.Separator();
				
				if (ImGui.MenuItem("Create new Project...", "Ctrl+ALT+N"))
					_openCreateProjectModal = true;

				if (ImGui.MenuItem("Open Project...", "Ctrl+ALT+O"))
					ShowOpenProjectDialog();

				if (ImGui.BeginMenu("Open recent project"))
				{
					ShowOpenRecentProjectMenu();
					ImGui.EndMenu();
				}

				ImGui.Separator();

				if (ImGui.MenuItem("Settings"))
					_settingsWindow.Open = true;
				
				ImGui.Separator();
				
				if (ImGui.MenuItem("Exit"))
					Application.Instance.Close();

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
				
				if(ImGui.MenuItem(LogWindow.s_WindowTitle))
					_editor.LogWindow.Open = true;

				ImGui.EndMenu();
			}
			
			if(ImGui.BeginMenu("Tools", true))
			{
				if(ImGui.MenuItem("Reload Scripts"))
					ScriptEngine.ReloadAssemblies();

#if GE_EDITOR_IMGUI_DEMO
				ImGui.Checkbox("Show ImGui Demo", &_showImguiDemoWindow);
#endif

				ImGui.EndMenu();
			}

			ShowPlayControls();

			ImGui.EndMainMenuBar();
		}

#endregion ImGui

#region Events

		/// Receive and dispatch global events
		public override void OnEvent(Event event)
		{
			EventDispatcher dispatcher = EventDispatcher(event);

			dispatcher.Dispatch<ImGuiRenderEvent>(scope (e) => OnImGuiRender(e));
			dispatcher.Dispatch<WindowResizeEvent>(scope (e) => OnWindowResize(e));
			dispatcher.Dispatch<KeyPressedEvent>(scope (e) => OnKeyPressed(e));
			dispatcher.Dispatch<MouseScrolledEvent>(scope (e) => OnMouseScrolled(e));
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

			_activeScene?.SetViewportSize(sizeX, sizeY);
		}
		
		private void GameViewportSizeChanged(Object sender, float2 viewportSize)
		{
			if(viewportSize.X <= 0 || viewportSize.Y <= 0)
				return;

			uint32 sizeX = (uint32)viewportSize.X;
			uint32 sizeY = (uint32)viewportSize.Y;

			_gameViewportTarget.Resize(sizeX, sizeY);

			_activeScene?.SetViewportSize(sizeX, sizeY);
		}

		private bool OnKeyPressed(KeyPressedEvent e)
		{
			// TODO: We need some kind of input system for stuff like this...

			bool control = Input.IsKeyPressed(Key.Control);
			bool alt = Input.IsKeyPressed(Key.Alt);
			bool shift = Input.IsKeyPressed(Key.Shift);
			
			if (!_camera.[Friend]BindMouse && control)
			{
				switch (e.KeyCode)
				{
				case .N:
					if (alt)
						// "Create new Project..."
						_openCreateProjectModal = true;
					else
						// "New Scene"
						CreateAndOpenNewScene();

					return true;
				case .O:
					if (alt && control)
						// "Open Project..."
						ShowOpenProjectDialog();
					else if (!alt && !control)
						// "Open Scene..."
						OpenScene();

					return true;
				case .S:
					if (shift)
						// "Save Scene as..."
						SaveCurrentSceneAs();
					else
						// "Save Scene"
						SaveCurrentScene();
					
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

#endregion
	}
}
