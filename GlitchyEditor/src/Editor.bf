using GlitchyEngine.World;
using ImGui;
using System;
using System.Collections;
using GlitchyEngine.Collections;
using GlitchyEditor.EditWindows;

namespace GlitchyEditor
{
	class Editor
	{
		private EcsWorld _ecsWorld;
		private Scene _scene;
		
		private EntityHierarchyWindow _entityHierarchyWindow ~ delete _;
		private ComponentEditWindow _componentEditWindow ~ delete _;
		private SceneViewportWindow _sceneViewportWindow = new .(this) ~ delete _;

		private List<EcsEntity> _selectedEntities = new .() ~ delete _;

		public EcsWorld World => _ecsWorld;

		public List<EcsEntity> SelectedEntities => _selectedEntities;

		public EntityHierarchyWindow EntityHierarchyWindow => _entityHierarchyWindow;
		public ComponentEditWindow ComponentEditWindow => _componentEditWindow;
		public SceneViewportWindow SceneViewportWindow => _sceneViewportWindow;

		/// Creates a new editor for the given world
		public this(Scene scene)
		{
			_scene = scene;
			_ecsWorld = _scene.[Friend]_ecsWorld;

			_entityHierarchyWindow = new EntityHierarchyWindow(_scene);
			_componentEditWindow = new ComponentEditWindow(_entityHierarchyWindow);
		}

		public void Update()
		{
			_entityHierarchyWindow.Show();
			_componentEditWindow.Show();
			_sceneViewportWindow.Show();
		}

		/// Creates a new entity with a transform component.
		internal EcsEntity CreateEntityWithTransform()
		{
			var entity = _ecsWorld.NewEntity();

			var transformComponent = ref *_ecsWorld.AssignComponent<TransformComponent>(entity);
			transformComponent = TransformComponent();

			var nameComponent = ref *_ecsWorld.AssignComponent<DebugNameComponent>(entity);
			nameComponent.SetName("Entity");

			return entity;
		}

		
		/// Returns whether or not all selected entities have the same parent.
		internal bool AllSelectionsOnSameLevel()
		{
			EcsEntity? parent = .InvalidEntity;

			for(var selectedEntity in _selectedEntities)
			{
				var parentComponent = _ecsWorld.GetComponent<ParentComponent>(selectedEntity);

				if(parent == .InvalidEntity)
				{
					parent = parentComponent?.Entity;
				}
				else if(parentComponent?.Entity != parent)
				{
					return false;
				}
			}

			return true;
		}

		/// Finds all children of the given entity and stores their IDs in the given list.
		internal void FindChildren(EcsEntity entity, List<EcsEntity> entities)
		{
			for(var (child, childParent) in _ecsWorld.Enumerate<ParentComponent>())
			{
				if(childParent.Entity == entity)
				{
					if(!entities.Contains(child))
						entities.Add(child);

					FindChildren(child, entities);
				}
			}
		}

		/// Deletes all selected entities and their children.
		internal void DeleteSelectedEntities()
		{
			List<EcsEntity> entities = scope .();

			for(var entity in _selectedEntities)
			{
				entities.Add(entity);

				FindChildren(entity, entities);
			}

			for(var entity in entities)
			{
				_ecsWorld.RemoveEntity(entity);
			}

			_selectedEntities.Clear();
		}

	}
}
