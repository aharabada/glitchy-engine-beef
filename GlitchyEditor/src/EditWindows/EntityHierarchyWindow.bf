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

		public this(Editor editor, Scene scene)
		{
			_editor = editor;
			SetContext(scene);
		}

		public void SetContext(Scene scene)
		{
			_selectedEntities.Clear();
			_scene = scene;
		}

		/*public bool SelectEntityWithId(uint32 id, bool addToSelection = false)
		{
			if (!addToSelection)
				_selectedEntities.Clear();

			_scene.[Friend]_ecsWorld.IsValid(id);

			_selectedEntities.Add();
		}*/

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
				if (Input.IsKeyReleased(.Control))
				{
					_selectedEntities.Clear();
				}

				var handle = _scene.[Friend]_ecsWorld.GetCurrentVersion(EcsEntity.[Friend]CreateEntityID(_editor.SceneViewportWindow.SelectedEntityId, 0));

				if (handle case .Ok(let h))
				{
					Entity e = .(h, _scene);
	
					_selectedEntities.Add(e);
				}
			}

			ShowEntityHierarchy();
			
			if ((ImGui.IsMouseDown(.Left) || ImGui.IsMouseDown(.Right)) && !ImGui.IsAnyItemHovered() && !ImGui.GetIO().KeyCtrl && ImGui.IsWindowHovered(.AllowWhenBlockedByPopup))
				_selectedEntities.Clear();

			ImGui.End();
		}
		
		/// Returns whether or not all selected entities have the same parent.
		internal bool AllSelectionsOnSameLevel()
		{
			EcsEntity? parent = .InvalidEntity;

			for(var selectedEntity in _selectedEntities)
			{
				var transformComponent = selectedEntity.GetComponent<TransformComponent>();

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
			for (var entity in _selectedEntities)
			{
				_scene.DestroyEntity(entity, true);
			}

			_selectedEntities.Clear();
		}

		private void ShowEntityHierarchyMenuBar()
		{
			if(ImGui.BeginMenuBar())
			{
				Show_ContextMenu_Create(true, true, true);

				Show_ContextMenu_Delete();

				if(ImGui.MenuItem("Delete", null, false, !_selectedEntities.IsEmpty) ||
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
			var newEntity = _scene.CreateEntity();

			var transformCmp = newEntity.GetComponent<TransformComponent>();
			// Last entity in list is the entity that has been selected last.
			transformCmp.Parent = entity?.Handle ?? .InvalidEntity;
		}
		
		/// Creates a new entity that is a parent of the selected entities.
		private void CreateParent()
		{
			if (_selectedEntities.IsEmpty || !AllSelectionsOnSameLevel())
			{
				Log.EngineLogger.Error("Cannot create parent entity.");
				return;
			}

			var commonParent = _selectedEntities.Front.GetComponent<TransformComponent>();

			var newEntity = _scene.CreateEntity();

			if(commonParent != null)
			{
				// parent of selected entities is parent of the new entity.
				// (which is why this doesn't work if the entities don't have the same parent)
				var newEntityTransform = newEntity.GetComponent<TransformComponent>();
				newEntityTransform.Parent = commonParent.Parent;
			}

			// new entity is parent of all selected entities.
			for(var selectedEntity in _selectedEntities)
			{
				var selectedTransform = selectedEntity.GetComponent<TransformComponent>();
				selectedTransform.Parent = newEntity.Handle;
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
						if (_selectedEntities.IsEmpty)
							_scene.CreateEntity();
						else
						{
							Entity? parent = _selectedEntities.Back.Parent;
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
					if(ImGui.MenuItem("Empty Child", null, false, !_selectedEntities.IsEmpty))
					{
						CreateChild(_selectedEntities.Back);
					}
					
					if(ImGui.IsItemHovered())
						ImGui.SetTooltip("Create a new Entity that is a child of the selected entity.");
				}

				if (allowParent)
				{
					if(ImGui.MenuItem("Parent", null, false, !_selectedEntities.IsEmpty && AllSelectionsOnSameLevel()))
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

			if(ImGui.MenuItem("Delete", null, false, !_selectedEntities.IsEmpty))
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

			var nameComponent = tree.Value.GetComponent<DebugNameComponent>();

			if(nameComponent != null)
			{
				name = nameComponent.DebugName;
			}
			else
			{
				name = scope:: $"Entity {(tree.Value.Handle.[Friend]Index)}";
			}

			ImGui.TreeNodeFlags flags = .OpenOnArrow | .DefaultOpen | .SpanAvailWidth;

			if(tree.Children.Count == 0)
				flags |= .Leaf;
			
			bool inSelectedList = _selectedEntities.Contains(tree.Value);
			
			if(inSelectedList)
				flags |= .Selected;

			bool isOpen = ImGui.TreeNodeEx((void*)(uint)tree.Value.Handle.[Friend]Index, flags, $"{name}");

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
				return;

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
						movedEntityTransform.Parent = tree.Value.Handle;
					}
				}

				ImGui.EndDragDropTarget();
			}

			bool clicked = ImGui.IsItemClicked(.Left);
			bool clickedRight = ImGui.IsItemClicked(.Right);

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
				if (inSelectedList && !clickedRight)
				{
					_selectedEntities.Remove(tree.Value);
					inSelectedList = false;
				}
				else
				{
					if (!ImGui.GetIO().KeyCtrl && !clickedRight)
					{
						_selectedEntities.Clear();
					}

					_selectedEntities.Add(tree.Value);
					inSelectedList = true;
				}
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
