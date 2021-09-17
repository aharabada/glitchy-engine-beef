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
		private EcsWorld _world;
		
		private EntityHierarchyWindow _entityHierarchyWindow = new .(this) ~ delete _;
		private ComponentEditWindow _componentEditWindow = new .(this) ~ delete _;
		private SceneViewportWindow _sceneViewportWindow = new .() ~ delete _;

		private List<Entity> _selectedEntities = new .() ~ delete _;

		public EcsWorld World => _world;

		public List<Entity> SelectedEntities => _selectedEntities;

		public EntityHierarchyWindow EntityHierarchyWindow => _entityHierarchyWindow;
		public ComponentEditWindow ComponentEditWindow => _componentEditWindow;
		public SceneViewportWindow SceneViewportWindow => _sceneViewportWindow;

		/// Creates a new editor for the given world
		public this(EcsWorld world)
		{
			_world = world;
		}

		public void Update()
		{
			_entityHierarchyWindow.Show();
			_componentEditWindow.Show();
			_sceneViewportWindow.Show();
		}

		/// Creates a new entity with a transform component.
		internal Entity CreateEntityWithTransform()
		{
			var entity = _world.NewEntity();

			var transformComponent = ref *_world.AssignComponent<TransformComponent>(entity);
			transformComponent = TransformComponent();

			var nameComponent = ref *_world.AssignComponent<DebugNameComponent>(entity);
			nameComponent.SetName("Entity");

			return entity;
		}

		
		/// Returns whether or not all selected entities have the same parent.
		internal bool AllSelectionsOnSameLevel()
		{
			Entity? parent = .InvalidEntity;

			for(var selectedEntity in _selectedEntities)
			{
				var parentComponent = _world.GetComponent<ParentComponent>(selectedEntity);

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
		internal void FindChildren(Entity entity, List<Entity> entities)
		{
			for(var (child, childParent) in _world.Enumerate<ParentComponent>())
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
			List<Entity> entities = scope .();

			for(var entity in _selectedEntities)
			{
				entities.Add(entity);

				FindChildren(entity, entities);
			}

			for(var entity in entities)
			{
				_world.RemoveEntity(entity);
			}

			_selectedEntities.Clear();
		}

	}
}
