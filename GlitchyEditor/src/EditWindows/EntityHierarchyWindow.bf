using GlitchyEngine.Collections;
using GlitchyEngine.World;
using ImGui;
using System;
using System.Collections;
using GlitchyEngine;

namespace GlitchyEditor.EditWindows
{
	using internal GlitchyEditor;

	/// A window for viewing and editing the scene hierarchy
	class EntityHierarchyWindow : EditorWindow
	{
		public const String s_WindowTitle = "Entity Hierarchy";

		/// Buffer for the entity search string.
		private char8[64] _entitySearchChars;

		private Scene _scene;

		private List<Entity> _selectedEntities = new .() ~ delete _;

		public List<Entity> SelectedEntities => _selectedEntities;

		public this(Scene scene)
		{
			SetContext(scene);
		}

		public void SetContext(Scene scene)
		{
			_scene = scene;
		}
		
		protected override void InternalShow()
		{
			if(!ImGui.Begin(s_WindowTitle, &_open, .MenuBar))
			{
				ImGui.End();
				return;
			}

			ShowEntityHierarchyMenuBar();

			ShowEntityHierarchy();

			ImGui.End();
		}
		
		/// Returns whether or not all selected entities have the same parent.
		internal bool AllSelectionsOnSameLevel()
		{
			EcsEntity? parent = .InvalidEntity;

			for(var selectedEntity in _selectedEntities)
			{
				var transformComponent = selectedEntity.GetComponent<SimpleTransformComponent>();

				if(parent == .InvalidEntity)
				{
					parent = transformComponent.Parent;
				}
				else if(transformComponent.Parent != parent)
				{
					return false;
				}
			}

			return true;
		}
		
		/// Finds all children of the given entity and stores their IDs in the given list.
		internal void FindChildren(EcsEntity entity, List<EcsEntity> entities)
		{
			for(var (child, childTransform) in _scene.[Friend]_ecsWorld.Enumerate<SimpleTransformComponent>())
			{
				if(childTransform.Parent == entity)
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
				entities.Add(entity.Handle);

				FindChildren(entity.Handle, entities);
			}

			for(var entityId in entities)
			{
				Entity entity = .(entityId, _scene);
				_scene.DestroyEntity(entity);
			}

			_selectedEntities.Clear();
		}

		private void ShowEntityHierarchyMenuBar()
		{
			if(ImGui.BeginMenuBar())
			{
				if(ImGui.BeginMenu("Create"))
				{
					if(ImGui.MenuItem("Empty Entity"))
					{
						_scene.CreateEntity();
					}

					if(ImGui.IsItemHovered())
						ImGui.SetTooltip("Create a new Entity.");

					if(ImGui.MenuItem("Empty Child", null, false, !_selectedEntities.IsEmpty))
					{
						var newEntity = _scene.CreateEntity();

						var transformCmp = newEntity.GetComponent<SimpleTransformComponent>();
						// Last entity in list is the entity that has been selected last.
						transformCmp.Parent = _selectedEntities.Back.Handle;
					}
					
					if(ImGui.IsItemHovered())
						ImGui.SetTooltip("Create a new Entity that is a child of the currently selected entity.");

					if(ImGui.MenuItem("Empty Parent", null, false, !_selectedEntities.IsEmpty && AllSelectionsOnSameLevel()))
					{
						var commonParent = _selectedEntities.Front.GetComponent<SimpleTransformComponent>();

						var newEntity = _scene.CreateEntity();

						if(commonParent != null)
						{
							// parent of selected entities is parent of the new entity.
							// (which is why this doesn't work if the entities don't have the same parent)
							var newEntityTransform = newEntity.GetComponent<SimpleTransformComponent>();
							newEntityTransform.Parent = commonParent.Parent;
						}

						// new entity is parent of all selected entities.
						for(var selectedEntity in _selectedEntities)
						{
							var selectedTransform = selectedEntity.GetComponent<SimpleTransformComponent>();
							selectedTransform.Parent = newEntity.Handle;
						}
					}
					
					if(ImGui.IsItemHovered())
						ImGui.SetTooltip("Create a new Entity that is the parent of the currently selected entities.");

					ImGui.EndMenu();
				}

				if(ImGui.IsItemHovered())
					ImGui.SetTooltip("Create a new Entity.");

				if(ImGui.MenuItem("Delete", null, false, !_selectedEntities.IsEmpty) || Input.IsKeyPressed(.Delete))
				{
					DeleteSelectedEntities();
				}

				if(ImGui.IsItemHovered())
					ImGui.SetTooltip("Deletes the selected Entities and their children.");

				ImGui.Text("Search:");

				ImGui.InputText(String.Empty, &_entitySearchChars, (.)_entitySearchChars.Count);

				ImGui.EndMenuBar();
			}
		}

		private void ImGuiPrintEntityTree(TreeNode<Entity> tree)
		{
			String name = null;

			var nameComponent = tree.Value.GetComponent<DebugNameComponent>();

			if(nameComponent != null)
			{
				name = nameComponent.DebugName;
			}
			else
			{
				name = scope:: $"Entity {(tree.Value.Handle.[Friend]Index)}";
			}

			ImGui.TreeNodeFlags flags = .OpenOnArrow | .DefaultOpen;

			if(tree.Children.Count == 0)
				flags |= .Leaf;
			
			bool inSelectedList = _selectedEntities.Contains(tree.Value);
			
			if(inSelectedList)
				flags |= .Selected;

			bool isOpen = ImGui.TreeNodeEx((void*)(uint)tree.Value.Handle.[Friend]Index, flags, $"{name}");

			if(ImGui.BeginDragDropSource())
			{
				ImGui.SetDragDropPayload("DND_Entity", &tree.Value, sizeof(Entity));

				ImGui.Text(name);

				ImGui.EndDragDropSource();
			}

			if(ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = ImGui.AcceptDragDropPayload("DND_Entity");

				if(payload != null)
				{
					Log.ClientLogger.AssertDebug(payload.DataSize == sizeof(Entity));

					Entity movedEntity = *(Entity*)payload.Data;

					bool dropLegal = true;

					Entity walker = tree.Value;

					// make sure the dropped entity is not a parent of the entity we dropped it on.
					while(true)
					{
						var parentTransform = walker.GetComponent<SimpleTransformComponent>();
						
						if(parentTransform.Parent == .InvalidEntity)
						{
							dropLegal = true;
							break;
						}
						else if(parentTransform.Parent == movedEntity.Handle)
						{
							dropLegal = false;
							break;
						}

						walker = .(parentTransform.Parent, _scene);
					}

					if(dropLegal)
					{
						var movedEntityTransform = movedEntity.GetComponent<SimpleTransformComponent>();
						movedEntityTransform.Parent = tree.Value.Handle;
					}
				}

				ImGui.EndDragDropTarget();
			}

			bool clicked = ImGui.IsItemClicked();

			if(isOpen)
			{
				for(var child in tree.Children)
				{
					ImGuiPrintEntityTree(child);
				}

				ImGui.TreePop();
			}

			if(clicked)
			{
				if(inSelectedList)
				{
					_selectedEntities.Remove(tree.Value);
				}
				else
				{
					if(!ImGui.GetIO().KeyCtrl)
					{
						_selectedEntities.Clear();
					}

					_selectedEntities.Add(tree.Value);
				}

				inSelectedList = !inSelectedList;
			}
		}

		private void ShowEntityHierarchy()
		{
			StringView searchString = StringView(&_entitySearchChars);

			if(searchString.IsWhiteSpace)
			{
				// Show entity hierarchy as tree
				
				TreeNode<Entity> root = scope .(Entity(.InvalidEntity, _scene));

				TreeNode<Entity> InsertIntoTree(Entity entity)
				{
					var transform = entity.GetComponent<SimpleTransformComponent>();

					if(transform == null)
					{
						return root.AddChild(entity);
					}
					else
					{
						var parentEntity = Entity(transform.Parent, _scene);

						var parentNode = root.FindNode(parentEntity);

						if(parentNode == null)
							parentNode = InsertIntoTree(parentEntity);

						return parentNode.AddChild(entity);
					}
				}
				
				for(var entityId in _scene.[Friend]_ecsWorld.Enumerate())
				{
					Entity entity = .(entityId, _scene);

					//if (!entity.HasComponent<EditorComponent>())
						InsertIntoTree(entity);
				}
				
				if(ImGui.TreeNodeEx("Scene", .DefaultOpen))
				{
					if(ImGui.BeginDragDropTarget())
					{
						ImGui.Payload* payload = ImGui.AcceptDragDropPayload("DND_Entity");

						if(payload != null)
						{
							Log.ClientLogger.AssertDebug(payload.DataSize == sizeof(Entity));

							Entity movedEntity = *(Entity*)payload.Data;

							// Also mark transform as dirty
							var transformComponent = movedEntity.GetComponent<SimpleTransformComponent>();
							transformComponent.Parent = .InvalidEntity;
							//transformComponent?.IsDirty = true;
						}

						ImGui.EndDragDropTarget();
					}

					for(var child in root.Children)
					{
						ImGuiPrintEntityTree(child);
					}

					ImGui.TreePop();
				}
			}
			// Otherwise
			else
			{
				// Show search results as flat list

				List<StringView> searchTokens = new:ScopedAlloc! .(searchString.Split(' ', .RemoveEmptyEntries));
				
				worldEnumeration:
				for(var entityId in _scene.[Friend]_ecsWorld.Enumerate())
				{
					Entity entity = .(entityId, _scene);

					String name = null;

					var nameComponent = entity.GetComponent<DebugNameComponent>();

					if(nameComponent != null)
					{
						name = nameComponent.DebugName;
					}
					else
					{
						name = scope:worldEnumeration $"Entity {entityId.[Friend]Index}";
					}

					StringView nameView = StringView(name);

					for(var token in searchTokens)
					{
						if(nameView.IndexOf(token, true) == -1)
						{
							continue worldEnumeration;
						}
					}

					ImGuiPrintEntityTree(scope .(entity));
				}
			}
		}
	}
}
