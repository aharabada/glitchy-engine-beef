using GlitchyEngine.World;
using ImGui;
using System;
using System.Collections;
using GlitchyEngine.Collections;
using GlitchyEditor.EditWindows;
using GlitchyEngine;
using GlitchyEditor.Assets;
using GlitchyEditor.CodeEditors;
using GlitchyEditor.Settings;
using GlitchyEditor.Multithreading;
using GlitchyEngine.Scripting;

namespace GlitchyEditor
{
	class Editor
	{
		private Scene _activeScene;
		private Scene _editorScene;

		private EditorContentManager _contentManager;
		private AssetThumbnailManager _thumbnailManager;

		private Project _currentProject;

		private EntityHierarchyWindow _entityHierarchyWindow ~ delete _;
		private ComponentEditWindow _componentEditWindow ~ delete _;
		private EditorViewportWindow _sceneViewportWindow ~ delete _;
		private GameViewportWindow _gameViewportWindow ~ delete _;
		private ContentBrowserWindow _contentBrowserWindow ~ delete _;
		private InspectorWindow _inspectorWindow ~ delete _;
		private AssetViewer _assetViewer ~ delete _;
		private LogWindow _logWindow ~ delete _;
		private SettingsWindow _settingsWindow ~ delete _;

		private List<ClosableWindow> _windows = new .() ~ DeleteContainerAndItems!(_);

		public Scene CurrentScene
		{
			get => _activeScene;
			set
			{
				if (_activeScene == value)
					return;

				_activeScene = value;
				_entityHierarchyWindow.SetContext(_activeScene);
			}
		}

		public Scene EditorScene
		{
			get => _editorScene;
			set => _editorScene = value;
		}

		public EditorContentManager ContentManager => _contentManager;

		public AssetThumbnailManager ThumbnailManager => _thumbnailManager;

		public Project CurrentProject
		{
			get => _currentProject;
			set => _currentProject = value;
		}

		public EntityHierarchyWindow EntityHierarchyWindow => _entityHierarchyWindow;
		public ComponentEditWindow ComponentEditWindow => _componentEditWindow;
		public EditorViewportWindow SceneViewportWindow => _sceneViewportWindow;
		public GameViewportWindow GameViewportWindow => _gameViewportWindow;
		public ContentBrowserWindow ContentBrowserWindow => _contentBrowserWindow;
		public InspectorWindow InspectorWindow => _inspectorWindow;
		public AssetViewer AssetViewer => _assetViewer;
		public LogWindow LogWindow => _logWindow;
		public SettingsWindow SettingsWindow => _settingsWindow;

		public EditorCamera* CurrentCamera { get; set; }

		public Event<EventHandler<StringView>> RequestOpenScene ~ _.Dispose();

		public SceneRenderer GameSceneRenderer {get; set;}
		public SceneRenderer EditorSceneRenderer {get; set;}

		private static Editor s_Instance;

		private IIdeAdapter _ideAdapter = null ~ delete _;

		public IIdeAdapter IdeAdapter
		{
			get => _ideAdapter;
			private set
			{
				delete _ideAdapter;
				_ideAdapter = value;
			}
		}

		public static Editor Instance => s_Instance;

		/// Creates a new editor for the given world
		public this(Scene activeScene, Scene editorScene, EditorContentManager contentManager, AssetThumbnailManager thumbnailManager)
		{
			Log.EngineLogger.AssertDebug(s_Instance == null, "Cannot create a second instance of a singleton.");
			s_Instance = this;

			EditorApp.Instance.Settings.OnApplySettings.Add(new (s, e) => {
				let activeIde = EditorApp.Instance.Settings.ScriptSettings.ActiveIde;
				if (activeIde != null)
				{
					switch (activeIde.Ide)
					{
					case .VisualStudio:
						IdeAdapter = new VisualStudioIdeAdapter(activeIde);
					case .Rider:
						IdeAdapter = new RiderIdeAdapter(activeIde);
					}
				}
				else
				{
					IdeAdapter = null;
				}
			});

			_activeScene = activeScene;
			_editorScene = editorScene;
			_contentManager = contentManager;
			_thumbnailManager = thumbnailManager;

			InitWindows();
		}

		public ~this()
		{
			s_Instance = null;
		}

		private void InitWindows()
		{
			_sceneViewportWindow = new EditorViewportWindow(this);
			_gameViewportWindow = new GameViewportWindow(this);
			_entityHierarchyWindow = new EntityHierarchyWindow(this, _activeScene);
			_componentEditWindow = new ComponentEditWindow();
			_contentBrowserWindow = new ContentBrowserWindow(this, (.)Application.Instance.ContentManager, _thumbnailManager);
			_inspectorWindow = new InspectorWindow(this);
			_assetViewer = new AssetViewer((.)Application.Instance.ContentManager);
			_logWindow = new LogWindow();
			_settingsWindow = new SettingsWindow();
		}

		public void Update()
		{
			PopupService.Instance.ImGuiDraw();

			_sceneViewportWindow.Show();
			_gameViewportWindow.Show();
			_entityHierarchyWindow.Show();
			//_componentEditWindow.Show();
			_contentBrowserWindow.Show();
			_inspectorWindow.Show();
			_assetViewer.Show();
			_logWindow.Show();
			_settingsWindow.Show();

			for (ClosableWindow window in _windows)
				window.Show();
		}

		public void AddWindow(ClosableWindow ownClosableWindow)
		{
			_windows.Add(ownClosableWindow);
		}

		public void RemoveWindow(ClosableWindow closableWindow)
		{
			_windows.Remove(closableWindow);
			delete closableWindow;
		}

		public void ShowSettings()
		{
			_settingsWindow.Open = true;
		}

		private void OpenIdeConfigurationPopup() {
			PopupService.Instance.OpenPopup("No IDE configured.", new (close) => {
				close = false;

				ImGui.TextUnformatted("In order to open a source file or the script project you need to configure an IDE to use.");

				if (ImGui.Button("Go to settings..."))
				{
					ShowSettings();
					SettingsWindow.HighlightSetting("Tools", "ide");
					close = true;
				}

				ImGui.SameLine();

				if (ImGui.Button("Cancel"))
				{
					close = true;
				}
			});
		}

		/// Wrapper for IdeAdapter.OpenScript that check whether or not an IDE Adapter is configured.
		/// If not, a popup will be show.
		public void OpenScript(StringView fileName, int lineNumber = 0, int columnNumber = 0)
		{
			if (IdeAdapter == null)
			{
				OpenIdeConfigurationPopup();
			}
			else
			{
				IdeAdapter.OpenScript(fileName, lineNumber, columnNumber);
			}
		}

		/// Wrapper for IdeAdapter.OpenScript that check whether or not an IDE Adapter is configured.
		/// If not, a popup will be show.
		public void OpenScriptProject()
		{
			if (IdeAdapter == null)
			{
				OpenIdeConfigurationPopup();
			}
			else
			{
				IdeAdapter.OpenScriptProject();
			}
		}

		/// Rebuilds the C# scripts.
		public BuildScriptsBackgroundTask BuildScripts(bool reloadAfterBuild = true, bool doCleanRebuild = false)
		{
			ScriptEngine.SuspendAssemblyWatcher();

			BuildScriptsBackgroundTask task = new .(EditorApp.Instance.Settings.ScriptSettings.DotNetExecutablePath, EditorApp.Instance.EditorLayer.CurrentProject, releaseBuild: false, doCleanRebuild){ DeleteWhenEnded = true };
			task.ContinueWith(new (task) => {
				ScriptEngine.ResumeAssemblyWatcher();

				EditorApp.Instance.ContentManager.AssetHierarchy.ScriptProjectDirtyManager.SetClean();

				if (reloadAfterBuild)
				{
					EditorApp.Instance.InvokeOnMainThread(new () => {
						ScriptEngine.ReloadAssemblies(retainScriptData: true);
						return true;
					});
				}
			});

			EditorApp.Instance.BackgroundTaskManager.StartBackgroundTask(task);

			return task;
		}

		public void ReloadScripts()
		{
			ScriptEngine.ReloadAssemblies(retainScriptData: true);
		}
	}
}
