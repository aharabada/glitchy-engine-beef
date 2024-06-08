using GlitchyEngine.World;
using ImGui;
using System;
using System.Collections;
using GlitchyEngine.Collections;
using GlitchyEditor.EditWindows;
using GlitchyEngine;
using GlitchyEditor.Assets;

namespace GlitchyEditor
{
	class Editor
	{
		private Scene _scene;

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

		public Scene CurrentScene
		{
			get => _scene;
			set
			{
				if (_scene == value)
					return;

				_scene = value;
				_entityHierarchyWindow.SetContext(_scene);
			}
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

		public EditorCamera* CurrentCamera { get; set; }

		public Event<EventHandler<StringView>> RequestOpenScene ~ _.Dispose();

		public SceneRenderer GameSceneRenderer {get; set;}
		public SceneRenderer EditorSceneRenderer {get; set;}

		private static Editor s_Instance;

		public static Editor Instance => s_Instance;

		/// Creates a new editor for the given world
		public this(Scene scene, EditorContentManager contentManager, AssetThumbnailManager thumbnailManager)
		{
			Log.EngineLogger.AssertDebug(s_Instance == null, "Cannot create a second instance of a singleton.");
			s_Instance = this;

			_scene = scene;
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
			_entityHierarchyWindow = new EntityHierarchyWindow(this, _scene);
			_componentEditWindow = new ComponentEditWindow();
			_contentBrowserWindow = new ContentBrowserWindow((.)Application.Get().ContentManager, _thumbnailManager);
			_inspectorWindow = new InspectorWindow(this);
			_assetViewer = new AssetViewer((.)Application.Get().ContentManager);
			_logWindow = new LogWindow();
		}

		public void Update()
		{
			_sceneViewportWindow.Show();
			_gameViewportWindow.Show();
			_entityHierarchyWindow.Show();
			//_componentEditWindow.Show();
			_contentBrowserWindow.Show();
			_inspectorWindow.Show();
			_assetViewer.Show();
			_logWindow.Show();
		}
	}
}
