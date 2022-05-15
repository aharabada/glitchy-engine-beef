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
		private Entity _currentCamera;
		
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

		public Entity CurrentCamera => _currentCamera;

		/// Creates a new editor for the given world
		public this(Scene scene)
		{
			_entityHierarchyWindow = new EntityHierarchyWindow(_scene);
			CurrentScene = scene;

			_componentEditWindow = new ComponentEditWindow(_entityHierarchyWindow);
		}

		public void Update()
		{
			_currentCamera = _scene.ActiveCamera;
			if (_currentCamera.IsValid)
			{
				var scriptComponent = _currentCamera.GetComponent<NativeScriptComponent>();
	
				if (var camController = scriptComponent?.Instance as EditorCameraController)
				{
					camController.IsEnabled = (SceneViewportWindow.HasFocus && Input.IsMouseButtonPressed(.RightButton));
				}
			}

			_entityHierarchyWindow.Show();
			_componentEditWindow.Show();
			_sceneViewportWindow.Show();
		}
	}
}
