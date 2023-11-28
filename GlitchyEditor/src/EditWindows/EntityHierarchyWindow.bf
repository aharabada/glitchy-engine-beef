using GlitchyEngine.Collections;
using GlitchyEngine.World;
using ImGui;
using System;
using System.Collections;
using GlitchyEngine;
using GlitchyEngine.Core;
using System.Diagnostics;

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

		private List<UUID> _selectedEntityIds = new .() ~ delete _;

		private Entity _entityToHighlight;

		/// Gets a list of selected entity IDs.
		public List<UUID> SelectedEntityIds => _selectedEntityIds;

		private List<Entity> _entitiesToUnfold = new .() ~ delete _;

		/// Gets the number of entities that are currently selected.
		public int SelectionSize => _selectedEntityIds.Count;

		/// Returns the Entity at the given index or null if it doesn't exist.
		public Entity GetSelectedEntity(int index)
		{
			var index;

			if (index < 0)
				index = _selectedEntityIds.Count + index;

			UUID id = _selectedEntityIds[index];

			Result<Entity> selectedEntity = _editor.CurrentScene.GetEntityByID(id);

			if (selectedEntity case .Ok(let entity))
				return entity;

			// TODO: The entity should always exist in the scene, I'm sure!
			// If we can assume that, then we can remove the nullable and make everything even easier!
			Runtime.FatalError(scope $"No entity exists with selected id \"{id}\".");
		}

		public void HighlightEntity(Entity e)
		{
			_entityToHighlight = e;

			Entity walker = _entityToHighlight;

			while (walker.Parent != null)
			{
				walker = walker.Parent.Value;

				_entitiesToUnfold.Add(walker);
			}
		}

		public this(Editor editor, Scene scene)
		{
			_editor = editor;
			SetContext(scene);
		}

		public void SetContext(Scene scene)
		{
			// We could have looked here first, then we wouldn't changed the selection system to use UUIDs...
			// We could have gotten the IDs here and simply searched for the corresponding entities in the new scene.
			//ClearEntitySelection();
			_scene = scene;
		}

		/*public bool SelectEntityWithId(uint32 id, bool addToSelection = false)
		{
			if (!addToSelection)
				_selectedEntities.Clear();

			_scene.[Friend]_ecsWorld.IsValid(id);

			_selectedEntities.Add();
		}*/

		/// Deselects all entities.
		public void ClearEntitySelection()
		{
			_selectedEntityIds.Clear();
		}

		/// Selects the given entity.
		/// @param entity The entity to select.
		/// @param clearOldSelection If true the previously selected entities will be deselected. If false, the given entity will be added to the current selection.
		public void SelectEntity(Entity entity, bool clearOldSelection = false)
		{
			if (clearOldSelection)
				ClearEntitySelection();

			_selectedEntityIds.Add(entity.UUID);
		}

		/// Deselects the given entity.
		/// @param entity The entity to deselect.
		public bool DeselectEntity(Entity entity)
		{
			return _selectedEntityIds.Remove(entity.UUID);
		}

		/// Returns whether or not the given entity is currently selected.
		public bool IsEntitySelected(Entity entity)
		{
			return _selectedEntityIds.Contains(entity.UUID);
		}

		protected override void InternalShow()
		{
			if(!ImGui.Begin(s_WindowTitle, &_open, .MenuBar))
			{
				ImGui.End();
				return;
			}

			ShowEntityHierarchyMenuBar();

			if (ImGui.BeginPopupContextWindow(s_WindowTitle))
			{
				Show_ContextMenu_Create(true, false, false);

				ImGui.EndPopup();
			}

			if (_editor.SceneViewportWindow.SelectionChanged)
			{
				var handle = _scene.[Friend]_ecsWorld.GetCurrentVersion(EcsEntity.[Friend]CreateEntityID(_editor.SceneViewportWindow.SelectedEntityId, 0));

				if (handle case .Ok(let h))
				{
					Entity e = .(h, _scene);

					SelectEntity(e, Input.IsKeyReleased(.Control));
				}
				else if (Input.IsKeyReleased(.Control))
				{
					ClearEntitySelection();
				}
			}

			ShowEntityHierarchy();
			
			if ((ImGui.IsMouseDown(.Left) || ImGui.IsMouseDown(.Right)) && !ImGui.IsAnyItemHovered() && !ImGui.GetIO().KeyCtrl && ImGui.IsWindowHovered(.AllowWhenBlockedByPopup))
				ClearEntitySelection();

			ImGui.End();
		}
		
		/// Returns whether or not all selected entities have the same parent.
		internal bool AllSelectionsOnSameLevel()
		{
			EcsEntity? parent = null;

			for (int i < SelectionSize)
			{
				Entity entity = GetSelectedEntity(i);

				var transformComponent = entity.GetComponent<TransformComponent>();

				if(parent == null)
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
			for(var (child, childTransform) in _scene.[Friend]_ecsWorld.Enumerate<TransformComponent>())
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
			for (int i < _selectedEntityIds.Count)
			{
				Entity selectedEntity = GetSelectedEntity(i);
				_scene.DestroyEntity(selectedEntity, true);
			}

			_selectedEntityIds.Clear();
		}

		private void ShowEntityHierarchyMenuBar()
		{
			if(ImGui.BeginMenuBar())
			{
				Show_ContextMenu_Create(true, true, true);

				Show_ContextMenu_Delete();

				if(ImGui.MenuItem("Delete", null, false, SelectionSize != 0) ||
					(Input.IsKeyPressed(.Delete) && ImGui.IsWindowHovered()))
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

		/// Creates a new entity that is a child of the given entity.
		private void CreateChild(Entity? entity)
		{
			let newEntity = _scene.CreateEntity();

			let transformCmp = newEntity.GetComponent<TransformComponent>();
			// Last entity in list is the entity that has been selected last.
			transformCmp.Parent = entity?.Handle ?? .InvalidEntity;
		}
		
		/// Creates a new entity that is a parent of the selected entities.
		private void CreateParent()
		{
			if (SelectionSize == 0 || !AllSelectionsOnSameLevel())
			{
				Log.EngineLogger.Error("Cannot create parent entity.");
				return;
			}

			let commonParent = GetSelectedEntity(0).GetComponent<TransformComponent>();

			let newEntity = _scene.CreateEntity();

			if(commonParent != null)
			{
				// parent of selected entities is parent of the new entity.
				// (which is why this doesn't work if the entities don't have the same parent)
				let newEntityTransform = newEntity.GetComponent<TransformComponent>();
				newEntityTransform.Parent = commonParent.Parent;
			}
			
			// new entity is parent of all selected entities.
			for (int i < SelectionSize)
			{
				let selectedTransform = GetSelectedEntity(i).GetComponent<TransformComponent>();
				selectedTransform?.Parent = newEntity.Handle;
			}
		}

		private void Show_ContextMenu_Create(bool allowEmpty = true, bool allowChild = true, bool allowParent = true)
		{
			if (ImGui.BeginMenu("Create"))
			{
				if (allowEmpty)
				{
					if(ImGui.MenuItem("Empty Entity"))
					{
						if (SelectionSize == 0)
							_scene.CreateEntity();
						else
						{
							Entity? parent = GetSelectedEntity(-1).Parent;
							CreateChild(parent);
						}
					}

					if(ImGui.IsItemHovered())
					{
						ImGui.SetTooltip("Create a new Entity.");
					}
				}

				if (allowChild)
				{
					if(ImGui.MenuItem("Empty Child", null, false, SelectionSize != 0))
					{
						Entity selectedEntity = GetSelectedEntity(-1);
						CreateChild(selectedEntity);
					}
					
					if(ImGui.IsItemHovered())
						ImGui.SetTooltip("Create a new Entity that is a child of the selected entity.");
				}

				if (allowParent)
				{
					if(ImGui.MenuItem("Parent", null, false, SelectionSize != 0 && AllSelectionsOnSameLevel()))
					{
						CreateParent();
					}

					if(ImGui.IsItemHovered())
						ImGui.SetTooltip("Create a new Entity that is the parent of the selected entities.");
				}

				ImGui.EndMenu();
			}

			if(ImGui.IsItemHovered())
				ImGui.SetTooltip("Create a new Entity.");
		}

		private bool Show_ContextMenu_Delete()
		{
			bool deleted = false;

			if(ImGui.MenuItem("Delete", null, false, SelectionSize != 0))
			{
				DeleteSelectedEntities();

				deleted = true;
			}

			if(ImGui.IsItemHovered())
				ImGui.SetTooltip("Deletes the selected Entities and their children.");

			return deleted;
		}

		private void ImGuiPrintEntityTree(TreeNode<Entity> tree)
		{
			String name = null;

			var nameComponent = tree.Value.GetComponent<NameComponent>();

			if(nameComponent != null)
			{
				name = scope:: .(nameComponent.Name);
			}
			else
			{
				name = scope:: $"Entity {(tree.Value.Handle.[Friend]Index)}";
			}

			ImGui.TreeNodeFlags flags = .OpenOnArrow | .DefaultOpen | .SpanAvailWidth | .OpenOnDoubleClick;

			if(tree.Children.Count == 0)
				flags |= .Leaf;
			
			bool inSelectedList = IsEntitySelected(tree.Value);
			
			if(inSelectedList)
				flags |= .Selected;

			if (_entitiesToUnfold.Contains(tree.Value))
			{
				_entitiesToUnfold.Remove(tree.Value);

				ImGui.SetNextItemOpen(true, .None);
			}

			bool isOpen = ImGui.TreeNodeEx((void*)(uint)tree.Value.Handle.[Friend]Index, flags, $"{name}");

			if (_entityToHighlight == tree.Value)
			{
				ImGui.SetScrollHereY(0);
				_entityToHighlight = .();
			}

			ImGui.PushID((void*)(uint)tree.Value.Handle.[Friend]Index);

			bool deleted = false;

			if (ImGui.BeginPopupContextItem("treeNodePopup"))
			{
				Show_ContextMenu_Create(true, true, true);
				deleted = Show_ContextMenu_Delete();

				ImGui.EndPopup();
			}

			ImGui.PopID();

			if (deleted)
			{
				if (isOpen)
					ImGui.TreePop();

				return;
			}

			bool isDragged = false;

			if(ImGui.BeginDragDropSource())
			{
				isDragged = true;

				ImGui.SetDragDropPayload(.Entity, &tree.Value, sizeof(Entity));

				ImGui.Text(name);

				ImGui.EndDragDropSource();
			}

			EntityDropTarget(tree.Value);

			bool clicked = ImGui.IsItemClicked() && !ImGui.IsItemToggledOpen();
			bool clickedRight = ImGui.IsItemClicked(.Right);
			bool hovered = ImGui.IsItemHovered();
			
			if(isOpen)
			{
				for(var child in tree.Children)
				{
					ImGuiPrintEntityTree(child);
				}

				ImGui.TreePop();
			}

			if (clicked || clickedRight)
			{
				lastClickedEntity = tree.Value;
			}

			if (!isDragged && (!ImGui.IsMouseDown(.Left) && !ImGui.IsMouseDown(.Right) && hovered) && tree.Value == lastClickedEntity)
			{
				if (inSelectedList && !clickedRight)
				{
					DeselectEntity(tree.Value);
					inSelectedList = false;
				}
				else
				{
					SelectEntity(tree.Value, !ImGui.GetIO().KeyCtrl && !clickedRight);
					inSelectedList = true;
				}

				lastClickedEntity = .();
			}
		}

		private void EntityDropTarget(Entity target)
		{
			if(ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = ImGui.AcceptDragDropPayload(.Entity);

				if(payload != null)
				{
					Log.ClientLogger.AssertDebug(payload.DataSize == sizeof(Entity));

					Entity movedEntity = *(Entity*)payload.Data;

					bool dropLegal = true;

					Entity walker = target;

					// make sure the dropped entity is not a parent of the entity we dropped it on.
					while(walker.IsValid)
					{
						var parentTransform = walker.GetComponent<TransformComponent>();
						
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
						var movedEntityTransform = movedEntity.GetComponent<TransformComponent>();
						movedEntityTransform.Parent = target.Handle;
					}
				}

				ImGui.EndDragDropTarget();
			}
		}

		private static Entity lastClickedEntity;

		private void ShowEntityHierarchy()
		{
			StringView searchString = StringView(&_entitySearchChars);

			if (_scene == null)
			{
				ImGui.TextUnformatted("<No scene open>");
				return;
			}

			if(searchString.IsWhiteSpace)
			{
				// Show entity hierarchy as tree
				
				TreeNode<Entity> root = scope .(Entity(.InvalidEntity, _scene));

				TreeNode<Entity> InsertIntoTree(Entity entity)
				{
					var transform = entity.GetComponent<TransformComponent>();

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

					InsertIntoTree(entity);
				}
				
				if(ImGui.TreeNodeEx("Scene", .DefaultOpen))
				{
					if(ImGui.BeginDragDropTarget())
					{
						ImGui.Payload* payload = ImGui.AcceptDragDropPayload(.Entity);

						if(payload != null)
						{
							Log.ClientLogger.AssertDebug(payload.DataSize == sizeof(Entity));

							Entity movedEntity = *(Entity*)payload.Data;

							// Also mark transform as dirty
							var transformComponent = movedEntity.GetComponent<TransformComponent>();
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

					StringView name = null;

					var nameComponent = entity.GetComponent<NameComponent>();

					if(nameComponent != null)
					{
						name = nameComponent.Name;
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

			// If the mouse was released and no entity took the chance to become selected we probably hovered the background while releasing -> select no entity
			if (!ImGui.IsMouseDown(.Left) && !ImGui.IsMouseDown(.Right))
				lastClickedEntity = .();
		}
	}
}
