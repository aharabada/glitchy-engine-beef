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

		private EntityHierarchyWindow _entityHierarchyWindow ~ delete _;
		private ComponentEditWindow _componentEditWindow ~ delete _;
		private SceneViewportWindow _sceneViewportWindow~ delete _;
		private ContentBrowserWindow _contentBrowserWindow ~ delete _;
		private PropertiesWindow _propertiesWindow ~ delete _;

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
		
		public EntityHierarchyWindow EntityHierarchyWindow => _entityHierarchyWindow;
		public ComponentEditWindow ComponentEditWindow => _componentEditWindow;
		public SceneViewportWindow SceneViewportWindow => _sceneViewportWindow;
		public ContentBrowserWindow ContentBrowserWindow => _contentBrowserWindow;
		public PropertiesWindow PropertiesWindow => _propertiesWindow;

		public EditorCamera* CurrentCamera { get; set; }

		public Event<EventHandler<StringView>> RequestOpenScene ~ _.Dispose();

		/// Creates a new editor for the given world
		public this(Scene scene, EditorContentManager contentManager)
		{
			_scene = scene;
			_contentManager = contentManager;

			InitWindows();
		}

		private void InitWindows()
		{
			_sceneViewportWindow = new SceneViewportWindow(this);
			_entityHierarchyWindow = new EntityHierarchyWindow(this, _scene);
			_componentEditWindow = new ComponentEditWindow(_entityHierarchyWindow);
			_contentBrowserWindow = new ContentBrowserWindow((.)Application.Get().ContentManager);
			_propertiesWindow = new PropertiesWindow(this);
		}

		public void Update()
		{
			_sceneViewportWindow.Show();
			_entityHierarchyWindow.Show();
			_componentEditWindow.Show();
			_contentBrowserWindow.Show();
			_propertiesWindow.Show();
		}
	}
}
