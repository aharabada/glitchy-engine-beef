using GlitchyEngine.World;
using ImGui;
using System;
using System.Collections;
using GlitchyEngine.Collections;
using GlitchyEditor.EditWindows;
using GlitchyEngine;

namespace GlitchyEditor
{
	class Editor
	{
		private Scene _scene;
		
		private EntityHierarchyWindow _entityHierarchyWindow ~ delete _;
		private ComponentEditWindow _componentEditWindow ~ delete _;
		private SceneViewportWindow _sceneViewportWindow = new .(this) ~ delete _;

		public EntityHierarchyWindow EntityHierarchyWindow => _entityHierarchyWindow;
		public ComponentEditWindow ComponentEditWindow => _componentEditWindow;
		public SceneViewportWindow SceneViewportWindow => _sceneViewportWindow;

		public Scene CurrentScene
		{
			get => _scene;
			set
			{
				_scene = value;
				_entityHierarchyWindow.SetContext(_scene);
			}
		}

		public EditorCamera* CurrentCamera { get; set; }

		/// Creates a new editor for the given world
		public this(Scene scene)
		{
			_entityHierarchyWindow = new EntityHierarchyWindow(this, _scene);
			CurrentScene = scene;

			_componentEditWindow = new ComponentEditWindow(_entityHierarchyWindow);
		}

		public void Update()
		{
			_entityHierarchyWindow.Show();
			_componentEditWindow.Show();
			_sceneViewportWindow.Show();
		}
	}
}
