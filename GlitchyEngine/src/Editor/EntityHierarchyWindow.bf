using GlitchyEngine.Collections;
using GlitchyEngine.World;
using ImGui;
using System;
using System.Collections;

namespace GlitchyEngine.Editor
{
	using internal GlitchyEngine.Editor;

	/// A window for viewing and editing the scene hierarchy
	class EntityHierarchyWindow
	{
		private Editor _editor;
		
		/// Buffer for the entity search string.
		private char8[] _entitySearchChars = new char8[64] ~ delete _;

		private bool _show = true;

		public Editor Editor => _editor;
		
		public bool Show
		{
			get => _show;
			set => _show = value;
		}

		public this(Editor editor)
		{
			_editor = editor;
		}
		
		public void Show()
		{
			if(!ImGui.Begin("Entity Hierarchy", null, .MenuBar))
			{
				ImGui.End();
				return;
			}

			ShowEntityHierarchyMenuBar();

			ShowEntityHierarchy();

			ImGui.End();
		}
		
		private void ShowEntityHierarchyMenuBar()
		{
			if(ImGui.BeginMenuBar())
			{
				if(ImGui.BeginMenu("Create"))
				{
					if(ImGui.MenuItem("Empty Entity"))
					{
						_editor.CreateEntityWithTransform();
					}

					if(ImGui.IsItemHovered())
						ImGui.SetTooltip("Create a new Entity with a transform component.");

					if(ImGui.MenuItem("Empty Child", null, false, !_editor.SelectedEntities.IsEmpty))
					{
						var newEntity = _editor.CreateEntityWithTransform();
						var parent = _editor.World.AssignComponent<ParentComponent>(newEntity);
						// Last entity in list is the entity that has been selected last.
						parent.Entity = _editor.SelectedEntities.Back;
					}
					
					if(ImGui.IsItemHovered())
						ImGui.SetTooltip("Create a new Entity that is a child of the currently selected entity.");

					if(ImGui.MenuItem("Empty Parent", null, false, !_editor.SelectedEntities.IsEmpty && _editor.AllSelectionsOnSameLevel()))
					{
						var commonParent = _editor.World.GetComponent<ParentComponent>(_editor.SelectedEntities.Front);

						var newEntity = _editor.CreateEntityWithTransform();

						if(commonParent != null)
						{
							// parent of selected entities is parent of the new entity.
							// (which is why this doesn't work if the entities don't have the same parent)
							var newEntityParent = _editor.World.AssignComponent<ParentComponent>(newEntity);
							newEntityParent.Entity = commonParent.Entity;
						}

						// new entity is parent of all selected entities.
						for(var selectedEntity in _editor.SelectedEntities)
						{
							var selectedEntityParent = _editor.World.AssignComponent<ParentComponent>(selectedEntity);
							selectedEntityParent.Entity = newEntity;
						}
					}
					
					if(ImGui.IsItemHovered())
						ImGui.SetTooltip("Create a new Entity that is the parent of the currently selected entities.");

					ImGui.EndMenu();
				}

				if(ImGui.IsItemHovered())
					ImGui.SetTooltip("Create a new Entity.");

				if(ImGui.MenuItem("Delete", null, false, !_editor.SelectedEntities.IsEmpty) || Input.IsKeyPressed(.Delete))
				{
					_editor.DeleteSelectedEntities();
				}

				if(ImGui.IsItemHovered())
					ImGui.SetTooltip("Deletes the selected Entities and their children.");

				ImGui.Text("Search:");

				ImGui.InputText(String.Empty, _entitySearchChars.Ptr, (.)_entitySearchChars.Count);

				ImGui.EndMenuBar();
			}
		}

		private void ImGuiPrintEntityTree(TreeNode<Entity> tree)
		{
			String name = null;

			var nameComponent = _editor.World.GetComponent<DebugNameComponent>(tree.Value);

			if(nameComponent != null)
			{
				name = nameComponent.DebugName;
			}
			else
			{
				name = scope:: $"Entity {((uint64)tree.Value.[Friend]Index)}";
			}

			ImGui.TreeNodeFlags flags = .OpenOnArrow;

			if(tree.Children.Count == 0)
				flags |= .Leaf;
			
			bool inSelectedList = _editor.SelectedEntities.Contains(tree.Value);
			
			if(inSelectedList)
				flags |= .Selected;

			bool isOpen = ImGui.TreeNodeEx(name, flags);

			if(ImGui.BeginDragDropSource())
			{
				ImGui.SetDragDropPayload("DND_Entity", &tree.Value, sizeof(Entity));

				ImGui.Text(name);

				ImGui.EndDragDropSource();
			}

			if(ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = &ImGui.AcceptDragDropPayload("DND_Entity");

				if(payload != null)
				{
					Log.ClientLogger.AssertDebug(payload.DataSize == sizeof(Entity));

					Entity movedEntity = *(Entity*)payload.Data;

					bool dropLegal = true;

					Entity walker = tree.Value;

					// make sure the dropped entity is not a parent of the entity we dropped it on.
					while(true)
					{
						var walkerParent = _editor.World.GetComponent<ParentComponent>(walker);

						if(walkerParent == null)
						{
							dropLegal = true;
							break;
						}
						else if(walkerParent.Entity == movedEntity)
						{
							dropLegal = false;
							break;
						}

						walker = walkerParent.Entity;
					}

					if(dropLegal)
					{
						var movedEntityParent = _editor.World.AssignComponent<ParentComponent>(movedEntity);
						movedEntityParent.Entity = tree.Value;
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
					_editor.SelectedEntities.Remove(tree.Value);
				}
				else
				{
					if(!ImGui.GetIO().KeyCtrl)
					{
						_editor.SelectedEntities.Clear();
					}

					_editor.SelectedEntities.Add(tree.Value);
				}

				inSelectedList = !inSelectedList;
			}
		}

		private void ShowEntityHierarchy()
		{
			StringView searchString = StringView(_entitySearchChars.Ptr);

			if(searchString.Length == 0)
			{
				// Show entity hierarchy as tree
				
				TreeNode<Entity> root = scope .(.InvalidEntity);

				TreeNode<Entity> AddEntity(Entity entity)
				{
					var parent = _editor.World.GetComponent<ParentComponent>(entity);

					if(parent == null)
					{
						return root.AddChild(entity);
					}
					else
					{
						var parentNode = root.FindNode(parent.Entity);

						if(parentNode == null)
							parentNode = AddEntity(parent.Entity);

						return parentNode.AddChild(entity);
					}
				}
				
				for(var entity in _editor.World.Enumerate())
				{
					AddEntity(entity);
				}
				
				if(ImGui.TreeNodeEx("Scene", .DefaultOpen))
				{
					if(ImGui.BeginDragDropTarget())
					{
						ImGui.Payload* payload = &ImGui.AcceptDragDropPayload("DND_Entity");

						if(payload != null)
						{
							Log.ClientLogger.AssertDebug(payload.DataSize == sizeof(Entity));

							Entity movedEntity = *(Entity*)payload.Data;

							_editor.World.RemoveComponent<ParentComponent>(movedEntity);

							// Also mark transform as dirty
							var transformComponent = _editor.World.GetComponent<TransformComponent>(movedEntity);
							transformComponent?.IsDirty = true;
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
				for(var entity in _editor.World.Enumerate())
				{
					String name = null;

					var nameComponent = _editor.World.GetComponent<DebugNameComponent>(entity);

					if(nameComponent != null)
					{
						name = nameComponent.DebugName;
					}
					else
					{
						name = scope:worldEnumeration $"Entity {entity.[Friend]Index}";
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
