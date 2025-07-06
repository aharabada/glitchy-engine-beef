using ImGui;
using System;
using System.IO;
using System.Linq;
using GlitchyEngine.Collections;
using System.Collections;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using GlitchyEngine.Content;
using GlitchyEngine;
using GlitchyEditor.Assets;
using System.Diagnostics;
using GlitchyEditor.CodeEditors;

namespace GlitchyEditor.EditWindows
{
	using internal GlitchyEditor.EditorContentManager;

	class AssetCreator
	{
		private String _name ~ delete _;
		private String _defaultFileName ~ delete _;
		private String _fileExtension ~ delete _;
		private CreateAssetFunc _doCreateAsset ~ delete _;

		private SubTexture2D _icon ~ _?.ReleaseRef();

		public delegate void CreateAssetFunc(StringView outputPath);

		public StringView Name => _name;
		public StringView DefaultFileName => _defaultFileName;
		public StringView FileExtension => _fileExtension;

		public CreateAssetFunc CreateAsset => _doCreateAsset;

		public SubTexture2D Icon => _icon;

		public this(StringView name, StringView defaultFileName, StringView fileExtension, CreateAssetFunc createAsset, SubTexture2D icon = null)
		{
			_name = new String(name);
			_defaultFileName = new String(defaultFileName);
			_fileExtension = new String(fileExtension);
			_doCreateAsset = createAsset;

			_icon = icon;
			_icon?.AddRef();
		}
	}

	class ContentBrowserWindow : EditorWindow
	{
		private append List<AssetCreator> _assetCreators = .() ~ ClearAndDeleteItems!(_);

		private typealias AssetCreatorTree = TreeNode<(StringView Name, AssetCreator Creator)>;

		private AssetCreatorTree _creatorTree = new AssetCreatorTree(("Create new", null)) ~ delete _;
		/// The last Asset Creator that was inserted.
		private AssetCreatorTree _lastInsertedAssetCreator = null;

		public const String s_WindowTitle = "Content Browser";

		class History
		{
			AssetHierarchy _hierarchy;

			public AssetHierarchy AssetHierarchy
			{
				get => _hierarchy;
				set => _hierarchy = value;
			}

			private append List<String> _history = .() ~ ClearAndDeleteItems!(_);
			private int _currentIndex = -1;

			public StringView CurrentDirectoryPath => _currentIndex >= 0 ? _history[_currentIndex] : "";

			public bool CanGoBack => _currentIndex > 0;
			public bool CanGoForward => (_currentIndex + 1) < _history.Count;

			public void Navigate(StringView nextPath)
			{
				_currentIndex++;
				_history.Insert(_currentIndex, new String(nextPath));

				TrimHistory();
			}

			private void TrimHistory()
			{
				while (_history.Count > (_currentIndex + 1))
				{
					delete _history.PopBack();
				}
			}

			public void Replace(StringView nextPath)
			{
				if (_currentIndex == -1)
				{
					_currentIndex = 0;
					_history.AddFront(new String(nextPath));
				}
				else
				{
					_history[_currentIndex].Set(nextPath);
				}

				TrimHistory();
			}

			public bool Back()
			{
				if (CanGoBack)
				{
					_currentIndex--;
					return true;
				}
				return false;
			}

			public bool Forward()
			{
				if (CanGoForward)
				{
					_currentIndex++;
					return true;
				}

				return false;
			}
		}

		private append History _directoryHistory = .();

		public StringView CurrentDirectory => _directoryHistory.CurrentDirectoryPath;
		
		TreeNode<AssetNode> _currentDirectoryNode => {
			Result<TreeNode<AssetNode>> currentDirectoryNode = _manager.AssetHierarchy.GetNodeFromPath(_directoryHistory.CurrentDirectoryPath);

			if (currentDirectoryNode case .Ok(TreeNode<AssetNode> currentDirectory))
			{
				return currentDirectory;
			}

			null
		};

		private append List<String> _selectedFiles = .() ~ ClearAndDeleteItems!(_);

		private append String _assetToRename = .();
		private char8[128] _renameFileNameBuffer;

		private AssetThumbnailManager _thumbnailManager;

		public static SubTexture2D s_FolderTexture;
		public static SubTexture2D s_FileTexture;

		public EditorContentManager _manager;

		// TODO: Update
		public StringView SelectedFile => _selectedFiles.First();

		char8[256] _newFileName = .();
		bool _showNewFile = false;
		AssetCreator _newFileCreator = null;

		char8[256] _filesFilter = .();
		bool _searchEverywhere;
		
		public Event<EventHandler<StringView>> OnFileSelected ~ _.Dispose();

		public this(Editor editor, EditorContentManager contentManager, AssetThumbnailManager thumbnailManager)
		{
			_editor = editor;
			_manager = contentManager;
			_thumbnailManager = thumbnailManager;
		}

		/// Registers an asset creator that will show up in the "Create new" drop down menu
		public void RegisterAssetCreator(AssetCreator assetCreator)
		{
			_assetCreators.Add(assetCreator);

			AssetCreatorTree tree = _creatorTree;

			for (StringView entryName in assetCreator.Name.Split('/'))
			{
				AssetCreatorTree nextNode = tree.Children.Where(scope (node) => node->Name == entryName).FirstOrDefault();

				// Create new node if we didn't find it
				nextNode ??= tree.AddChild((entryName, null));

				tree = nextNode;
			}

			if (tree->Creator == null)
			{
				tree->Creator = assetCreator;
			}

			_lastInsertedAssetCreator = tree;
		}

		/// Adds a seperator line after the asset creator that was last added.
		public void InsertAssetCreatorSeparator()
		{
			AssetCreatorTree parent = _lastInsertedAssetCreator.Parent;

			// Separators have an empty name and no creator!
			parent.AddChild(("", null));
		}

		private SelectionMode _selectionMode;
		private bool _addToSelection;
		
		bool _wantsDelete = false;

		private void NavigateForward()
		{
			if (_directoryHistory.Forward())
			{
				_selectedFiles.ClearAndDeleteItems();
			}
		}

		private void NavigateBack()
		{
			if (_directoryHistory.Back())
			{
				_selectedFiles.ClearAndDeleteItems();
			}
		}

		private void Navigate(TreeNode<AssetNode> node)
		{
			_directoryHistory.Navigate(node->Path);
			_selectedFiles.ClearAndDeleteItems();
		}
		
		private bool CanNavigateUp => _currentDirectoryNode.Parent != _manager.AssetHierarchy.RootNode;

		private void NavigateUp()
		{
			if (CanNavigateUp)
			{
				Navigate(_currentDirectoryNode.Parent);
			}
		}

		protected override void InternalShow()
		{
			_manager.Update();

			// Show History
			if (ImGui.Begin("Debug History"))
			{
				ImGui.CollapsingHeader("History");
				for (String path in _directoryHistory.[Friend]_history)
				{
					if (_directoryHistory.CurrentDirectoryPath === StringView(path))
					{
						ImGui.Text("==>");
						ImGui.SameLine();
					}
					ImGui.Text(path);
				}

				ImGui.CollapsingHeader("Selected Files");

				for (String path in _selectedFiles)
				{
					ImGui.Text(path);
				}

				ImGui.CollapsingHeader("Selection Rect");
				
				//if (!_selectionRectStart.X.IsNaN)
				{
					ImGui.TextUnformatted(_rectangleSelection.ToString(.. scope .()));
				}

				ImGui.End();
			}
			
			// Make sure we are in an existing directory.
			if (!_manager.AssetHierarchy.FileExists(CurrentDirectory))
			{
				_directoryHistory.Replace(_manager.AssetDirectory);
			}
			
			/*let originalWindowPadding = ImGui.GetStyle().WindowPadding;
			ImGui.PushStyleVar(.WindowPadding, float2(0,0));
			defer ImGui.PopStyleVar();*/

			if(!ImGui.Begin(s_WindowTitle, &_open, .None))
			{
				ImGui.End();
				return;
			}
			
			//ImGui.SetCursorPosY(ImGui.GetCursorPosY() + originalWindowPadding.y);

			DrawNavigationBar();

			// Update selection modifies
			{
				_addToSelection = Input.IsKeyPressed(.Control);

				if (Input.IsKeyPressed(.Shift))
				{
					_selectionMode = .Range;
				}
				else
				{
					_selectionMode = .SingleFile;
				}
			}

			// Remove paths from selection that no longer exist.
			for (String path in _selectedFiles)
			{
				Result<TreeNode<AssetNode>> node = _manager.AssetHierarchy.GetNodeFromPath(path);
				if (node case .Err)
				{
					@path.Remove();
					delete path;
				}
			}

			// Deletion
			{
				if (Input.IsKeyPressing(.Delete) && _selectedFiles.Count > 0)
				{
					_wantsDelete = true;
				}

				if (_wantsDelete)
				{
					ImGui.OpenPopup("Delete?");
					_wantsDelete = false;
				}

				DrawDeleteItemPopup();
			}

			ImGui.PushStyleVar(.CellPadding, .(0, 0));

			bool alt_pressed = ImGui.GetIO().KeyAlt;

			// Table with two columns, one for Directory-Sidebar and one for File-Browser
			if (ImGui.BeginTable("table", 2, .BordersInnerV | .Resizable | .Reorderable | .NoPadOuterX))
			{
				if (alt_pressed)
				{
					// Header anzeigen, damit sie neu angeordnet werden können
					ImGui.TableSetupColumn("Folder Hierarchy");
					ImGui.TableSetupColumn("Files");
					ImGui.TableHeadersRow();
				}

                ImGui.TableNextRow();
                ImGui.TableSetColumnIndex(0);

				if (ImGui.BeginChild("Sidebar"))
				{
					DrawDirectorySideBar();
				
					ImGui.EndChild();
				}

				ImGui.TableNextColumn();
				
				DrawSearchBar();

				ImGui.Separator();

				if (ImGui.BeginChild("Files"))
				{
					Result<TreeNode<AssetNode>> currentDirectoryNode = _manager.AssetHierarchy.GetNodeFromPath(_directoryHistory.CurrentDirectoryPath);

					if (currentDirectoryNode case .Ok(TreeNode<AssetNode> currentDirectory))
					{
						DrawCurrentDirectory(currentDirectoryNode);
					}

					// Context menu when clicking on the background.
					if (ImGui.BeginPopupContextWindow("FilePopup", .AnyPopup | .MouseButtonRight))
					{
					    ShowContextMenu();
					    ImGui.EndPopup();
					}

					ImGui.EndChild();
					
					if (!ImGui.IsAnyItemHovered() && (ImGui.IsItemClicked(.Left) || ImGui.IsItemClicked(.Right)))
					{
						_selectedFiles.ClearAndDeleteItems();
					}
					
					if (currentDirectoryNode case .Ok(TreeNode<AssetNode> currentDirectory))
					{
						FileDropTarget(currentDirectory, .External);
					}
				}

				ImGui.EndTable();
			}

			ImGui.PopStyleVar(1);

			ImGui.End();
		}

		private bool IsFileSelected(StringView fullFilePath)
		{
			return _selectedFiles.ContainsAlt(fullFilePath);
		}

		enum SelectionMode
		{
			SingleFile,
			Range
		}

		private void SelectFile(StringView fullFilePath, bool clearOldSelection, SelectionMode mode, bool toggle = true)
		{
			if (clearOldSelection)
			{
				_selectedFiles.ClearAndDeleteItems();
			}

			if (mode == .SingleFile && toggle)
			{
				if (IsFileSelected(fullFilePath))
				{
					String oldPath = _selectedFiles.GetAndRemoveAlt(fullFilePath);
					delete oldPath;
				}
				else
				{
					_selectedFiles.Add(new String(fullFilePath));
				}
			}
			else if (mode == .SingleFile && !toggle)
			{
				if (!IsFileSelected(fullFilePath))
				{
					_selectedFiles.Add(new String(fullFilePath));
				}
			}
			else if (mode == .Range)
			{
				if (IsFileSelected(fullFilePath))
				{
					String oldPath = _selectedFiles.GetAndRemoveAlt(fullFilePath);
					delete oldPath;
				}
				else
				{
					_selectedFiles.Add(new String(fullFilePath));
				}
			}
			

			// TODO: Update event to also provide all selected paths?
			OnFileSelected(this, fullFilePath);
		}

		private void DeselectFile(StringView fullFilePath)
		{
			String oldPath = TrySilent!(_selectedFiles.GetAndRemoveAlt(fullFilePath));
			delete oldPath;
		}

		private void DrawSearchBar()
		{
			ImGui.TextUnformatted("Search:");
			ImGui.SameLine();
			ImGui.InputText("##search", &_filesFilter, _filesFilter.Count);
			ImGui.SameLine();
			ImGui.Checkbox("Search everywhere", &_searchEverywhere);
		}

		private void ShowContextMenu()
		{
			if (_selectedFiles.IsEmpty)
			{
				ShowCurrentFolderContextMenu();
			}
			else
			{
				ShowItemContextMenu();
			}
		}

		/// Renders the context menu that is shown when the user right clicks on the background of the file browser.
		private void ShowCurrentFolderContextMenu()
		{
			if (ImGui.MenuItem("Open in file browser..."))
			{
				if (Path.OpenFolder(CurrentDirectory) case .Err)
					Log.EngineLogger.Error("Failed to open directory in file browser.");
			}
			
			ImGui.AttachTooltip("Opens the current folder in the systems file browser.");

			if (ImGui.BeginMenu("Copy path"))
			{
				if (ImGui.MenuItem("Full path"))
				{
					ImGui.SetClipboardText(CurrentDirectory.ToScopeCStr!());
				}
				
				ImGui.AttachTooltip("Copies the full file path of the current folder.");

				if (ImGui.MenuItem("Asset identifier"))
				{
					Result<TreeNode<AssetNode>> assetNode = _manager.AssetHierarchy.GetNodeFromPath(CurrentDirectory);

					if (assetNode case .Ok(let treeNode))
					{
						ImGui.SetClipboardText(treeNode->Identifier.FullIdentifier.Ptr);
					}
				}

				ImGui.AttachTooltip("Copies the asset identifier of the current folder.");

				ImGui.EndMenu();
			}

			ImGui.Separator();

			ShowCreateContextMenu(_creatorTree);
			
			ImGui.Separator();

			if (ImGui.MenuItem("Open C# Project..."))
			{
				RiderIdeAdapter.OpenScriptProject();
			}

			ImGui.AttachTooltip("Opens the C# Solution of this project.");
		}

		/// Shows the menu for the given asset creator tree.
		private void ShowCreateContextMenu(AssetCreatorTree subtree)
		{
			// Separators have an empty name and no creator
			if (subtree->Name.IsWhiteSpace && subtree->Creator == null)
			{
				ImGui.Separator();

				return;
			}

			if (subtree.Children.Count == 0)
			{
				if (ImGui.MenuItem(subtree->Name.ToScopeCStr!()))
				{
					ShowNewFile(subtree->Creator);
				}
			}
			else
			{
				if (ImGui.BeginMenu(subtree->Name.ToScopeCStr!()))
				{
					for (let node in subtree.Children)
					{
						ShowCreateContextMenu(node);
					}

					ImGui.EndMenu();
				}
			}
		}

		/// Shows a dummy file in the asset browser where the user can enter a file name and create an asset.
		private void ShowNewFile(AssetCreator creator)
		{
			_newFileCreator = creator;
			creator.DefaultFileName.CopyTo(_newFileName);
			_showNewFile = true;
		}

		/// Hides the dummy file.
		private void HideNewFile()
		{
			_newFileCreator = null;
			_showNewFile = false;
			_newFileName = .();
		}

		/// Creates a new asset with the given creator
		private void CreateAsset()
		{
			if (!Directory.Exists(CurrentDirectory))
			{
				Log.EngineLogger.Error($"Directory {CurrentDirectory} doesn't exist.");
				return;
			}
			
			String currentFile = scope String();
			Path.Combine(currentFile, CurrentDirectory, StringView(&_newFileName));

			// Add file extension, if necessary
			if (!currentFile.EndsWith(_newFileCreator.FileExtension))
			{
				currentFile.Append(_newFileCreator.FileExtension);
			}

			StringView fileWithoutExtension = currentFile[0...^(_newFileCreator.FileExtension.Length + 1)];

			// If the file already exists find a unused number to attach to the end.
			int i = 0;
			while (File.Exists(currentFile))
			{
				i++;
				currentFile.Set(fileWithoutExtension);
				currentFile.AppendF($"({i})");
				currentFile.Append(_newFileCreator.FileExtension);
			}

			_newFileCreator.CreateAsset(currentFile);

			HideNewFile();
		}

		/// Renders a sidebar that shows a tree of all directories in the asset folder.
		private void DrawDirectorySideBar()
		{
			for(var child in _manager.AssetHierarchy.RootNode.Children)
			{
				ImGuiPrintEntityTree(child);
			}
		}

		/// Renders an ImGui tree of all directories in the given tree.
		/// @param tree The file hierarchy of which to render all directories.
		private void ImGuiPrintEntityTree(TreeNode<AssetNode> tree)
		{
			if (!tree->IsDirectory)
				return;

			String name = tree->Name;

			ImGui.TreeNodeFlags flags = .OpenOnArrow | .SpanAvailWidth;

			if(tree.Children.Where(scope (node) => node->IsDirectory).Count() == 0)
				flags |= .Leaf;

			if (tree->Path == CurrentDirectory)
				flags |= .Selected;

			// TODO: this kinda works, but the user should be able to close the directory
			/*if (_manager.AssetHierarchy.GetNodeFromPath(_currentDirectory) case .Ok(let currentTreeNode))
			{
				if (currentTreeNode.IsInSubtree(tree))
					ImGui.SetNextItemOpen(true);
			}*/

			bool isOpen = ImGui.TreeNodeEx(name, flags, $"{name}");

			FileDropTarget(tree, .Internal | .External);

			if (!ImGui.IsItemToggledOpen() && ImGui.IsItemClicked(.Left))
			{
				_directoryHistory.Navigate(tree->Path);
				_selectedFiles.ClearAndDeleteItems();
			}

			if(isOpen)
			{
				for(var child in tree.Children)
				{
					ImGuiPrintEntityTree(child);
				}

				ImGui.TreePop();
			}
		}

		const float2 padding = .(24, 24);

		private ImGui.RectangleSelectionData _rectangleSelection;

		/// Renders the contents of _currentDirectory. Returns the node of the current directory, or null if the browser isn't in a directory.
		private void DrawCurrentDirectory(TreeNode<AssetNode> currentDirectoryNode)
		{
			if (ImGui.IsWindowHovered())
			{
				// TODO: Come up with a good hotkey system...
				if (Input.IsKeyPressed(.Alt))
				{
					if (Input.IsKeyPressing(.Up))
					{
						NavigateUp();
					}

					if (Input.IsKeyPressing(.Left))
					{
						NavigateBack();
					}

					if (Input .IsKeyPressing(.Right))
					{
						NavigateForward();
					}
				}

				if (Input.IsMouseButtonPressing(.XButton1))
				{
					NavigateBack();
				}

				if (Input.IsMouseButtonPressing(.XButton2))
				{
					NavigateForward();
				}
			}

			List<TreeNode<AssetNode>> directoryEntries = scope List<TreeNode<AssetNode>>();
			
			StringView searchFilter = StringView(&_filesFilter);

			if (_searchEverywhere && searchFilter.Length > 0)
			{
				_manager.AssetHierarchy.[Friend]_assetRootNode.ForEach(scope (node) =>
				{
					if (node->Name.Contains(searchFilter, ignoreCase: true))
					{
						directoryEntries.Add(node);
					}
				});
			}
			else
			{
				if (currentDirectoryNode == null)
				{
					ImGui.TextUnformatted("Failed to display contents of directory.");
					return;
				}

				currentDirectoryNode.Children.Where((entry) => entry->Name.Contains(searchFilter, true)).ToList(directoryEntries);
			}

			directoryEntries.Sort((entry1, entry2) => {
				// Sort so that directories are before files.
				int score = entry2->IsDirectory <=> entry1->IsDirectory;

				if (score == 0)
				{
					// If both are either directories or files sort alphabetically.
					score = StringView.Compare(entry1->Name, entry2->Name, ignoreCase: true);
				}

				return score;
			});

			float buttonsPerRow = ImGui.GetContentRegionAvail().x / (IconSize.X + ImGui.GetStyle().ItemSpacing.x);
			int actualButtonsPerRow = (int)buttonsPerRow;

			float actualSpace = (ImGui.GetContentRegionAvail().x - actualButtonsPerRow * IconSize.X) / (actualButtonsPerRow);

			int column = 0;

			for (var entry in directoryEntries)
			{
			    ImGui.PushID(entry->Path);

				DrawDirectoryEntry(entry);

				column++;

				if (column < actualButtonsPerRow)
					ImGui.SameLine((IconSize.X + actualSpace) * column);
				else
					column = 0;

				ImGui.PopID();
			}
			
			ImGui.BeginRectangleSelection(ref _rectangleSelection, ImGui.IsMouseDown(.Left) || ImGui.IsMouseDown(.Right));

			if (_showNewFile)
			{
			    ImGui.PushID("New File");
	
				ShowNewFile();
	
				ImGui.PopID();
			}
		}
		
		float _zoom = 1.0f;
		static readonly float2 IconBaseSize = .(100, 100);

		float2 IconSize => IconBaseSize * _zoom;

		enum DropTargetMode
		{
			Internal = 1,
			External = 2
		}

		/// Makes a drop target for the given asset node that files and directories can be dropped on, so that Files can be moved
		private void FileDropTarget(TreeNode<AssetNode> dropTarget, DropTargetMode mode)
		{
			if (dropTarget != null && dropTarget->IsDirectory && ImGui.BeginDragDropTarget())
			{
				bool allowDrop = false;

				if (mode.HasFlag(.Internal))
				{
					ImGui.Payload* peekPayload = ImGui.AcceptDragDropPayload(.ContentBrowserItem, .AcceptBeforeDelivery);

					if (peekPayload != null)
					{
						StringView assetIdentifier = .((char8*)peekPayload.Data, (int)peekPayload.DataSize);

						allowDrop = assetIdentifier != dropTarget->Identifier;

						if (allowDrop && peekPayload.IsDelivery())
						{
							_manager.AssetHierarchy.MoveFileToNode(assetIdentifier, dropTarget);
						}
					}
				}

				if (mode.HasFlag(.External))
				{
					ImGui.Payload* peekPayload = ImGui.AcceptDragDropPayload(.ExternFiles, .AcceptBeforeDelivery);

					if (peekPayload != null)
					{
						if (peekPayload.IsDelivery())
						{
							Log.EngineLogger.Info($"Dropping into {dropTarget->Path}");

							List<String> droppedFiles = (.)Internal.UnsafeCastToObject(*(void**)peekPayload.Data);

							_manager.AssetHierarchy.CopyExternFilesToNodeBackground(dropTarget, droppedFiles, .None);

							/*for (String path in droppedFiles)
							{
								Log.EngineLogger.Info($"Dropping file {path}");
								
								//_manager.AssetHierarchy.CopyExternFileToNodeBackground(dropTarget, path, .None);
							}*/
						}
						else
						{
							EditorLayer.SetDropEffect(.Copy);

							if (dropTarget->Path == CurrentDirectory)
							{
								ImGui.SetTooltip($"Copy here ({dropTarget->Name})");
							}
							else
							{
								ImGui.SetTooltip($"Copy to {dropTarget->Name}");
							}
						}
					}
				}	

				ImGui.EndDragDropTarget();
			}
		}

		/// Renders the button for the given directory entry.
		private void DrawDirectoryEntry(TreeNode<AssetNode> entry)
		{
			ImGui.PushStyleVar(.WindowPadding, .(0, 0));
			ImGui.PushStyleVar(.FramePadding, .(0, 0));
			ImGui.PushStyleVar(.ItemSpacing, .(0, 0));

			defer {ImGui.PopStyleVar(3); }

			ImGui.BeginGroup();

			if (IsFileSelected(entry->Path))
			{
				var color = ImGui.GetStyleColorVec4(.ButtonHovered);
				ImGui.PushStyleColor(.Button, *color);
			}
			else
			{
				ImGui.PushStyleColor(.Button, ImGui.Vec4(0, 0, 0, 0));
			}

			// TODO: preview images
			// TODO: Special Icon for back-folder?
			SubTexture2D image = _thumbnailManager.GetThumbnail(entry.Value);

			ImGui.ImageButton("FileImage", image, (.)IconSize);

			if (ImGui.IsRectangleSelecting(ref _rectangleSelection))
			{
				if (ImGui.IsInRectangleSelection(ref _rectangleSelection))
				{
					SelectFile(entry->Path, false, .SingleFile, false);
				}
				else
				{
					DeselectFile(entry->Path);
				}
			}

			ImGui.PopStyleColor();

			if (ImGui.BeginDragDropSource())
			{
				ImGui.SetDragDropPayload(.ContentBrowserItem, entry->Identifier.FullIdentifier.Ptr, (uint64)entry->Identifier.FullIdentifier.Length, .Once);

				float2 dndIconSize = (ImGui.GetFontSize() * 2.0f).XX;

				ImGui.Image(image, (.)dndIconSize);

				ImGui.SameLine();

				ImGui.SetCursorPosY((dndIconSize.X - ImGui.GetFontSize()) / 2);

				ImGui.Text(entry->Identifier.FullIdentifier.Ptr);

				ImGui.EndDragDropSource();
			}

			FileDropTarget(entry, .Internal | .External);

			if (ImGui.IsItemHovered() && ImGui.IsMouseClicked(.Left))
			{
				SelectFile(entry->Path, !_addToSelection, _selectionMode);
				// TODO: WHY?
				_assetToRename.Clear();
			}
			
			if (ImGui.IsItemHovered() && ImGui.IsMouseClicked(.Right))
			{
				// If we right click on a selected file we want to open the context menu for all selected files
				// If we click on an unselected file we want to select it (and potentially clear the selection)
				if (!IsFileSelected(entry->Path))
				{
					SelectFile(entry->Path, !_addToSelection, _selectionMode);
				}
				// TODO: WHY?
				_assetToRename.Clear();
			}

			if (ImGui.IsItemHovered() && ImGui.IsMouseDoubleClicked(.Left))
			{
				if (ImGui.IsKeyDown(.LeftCtrl))
					OpenPropertiesWindow(entry);
				else
					OpenEntry(entry);
			}

			if (_assetToRename == entry->Path)
			{
				ImGui.PushItemWidth((.)IconSize.X);

				ImGui.InputText("##renameBox", &_renameFileNameBuffer, _renameFileNameBuffer.Count - 1, .AutoSelectAll);

				ImGui.PopItemWidth();
				
				ImGui.SetKeyboardFocusHere(-1);

				if (ImGui.IsKeyDown(.Escape))
				{
					_assetToRename.Clear();
				}
				else if (ImGui.IsItemDeactivatedAfterEdit())
				{
					StringView newName = StringView(&_renameFileNameBuffer);

					if (!newName.IsWhiteSpace)
						_manager.AssetHierarchy.RenameFile(entry.Value, newName);
					
					_assetToRename.Clear();
				}
				else if (ImGui.IsItemDeactivated())
				{
					_assetToRename.Clear();
				}
			}
			else
			{
				ImGui.PushTextWrapPos(ImGui.GetCursorPosX() + IconSize.X);
				ImGui.Text(entry->Name);
				ImGui.PopTextWrapPos();
			}

			/*if (ImGui.BeginPopupContextWindow())
			{
			    ShowItemContextMenu(entry, itemType, ref _wantsDelete);
			    ImGui.EndPopup();
			}*/

			// TODO: Sub assets are probably borked now... I don't know if they ever worked, didn't test them
			if (entry->SubAssets?.Count > 0)
			{
				// Button for revealing sub assets (e.g. Meshes in 3D-Model)

				ImGui.SameLine();
				if (ImGui.Button(">"))
					ImGui.OpenPopup("SubAssets");
			}

			if (ImGui.BeginPopup("SubAssets", .Popup))
			{
				for (var subAsset in entry->SubAssets)
				{
					ImGui.Button(subAsset.Name);

					if (ImGui.BeginDragDropSource())
					{
						String fullpath = scope String(entry->Path);
						fullpath.AppendF($"#{subAsset.Name}");

						ImGui.SetDragDropPayload(.ContentBrowserItem, fullpath.CStr(), (.)fullpath.Length, .Once);

						ImGui.EndDragDropSource();
					}
				}

				ImGui.EndPopup();
			}

			ImGui.EndGroup();

			ImGui.AttachTooltip(entry->Name);
		}

		/// Renders the button for the given directory item.
		private void ShowNewFile()
		{
			ImGui.PushStyleVar(.WindowPadding, .(0, 0));
			ImGui.PushStyleVar(.FramePadding, .(0, 0));
			ImGui.PushStyleVar(.ItemSpacing, .(0, 0));

			defer { ImGui.PopStyleVar(3); }

			float2 DirectoryItemSize = IconSize + (float2)ImGui.GetStyle().WindowPadding * 2 + float2(0, ImGui.GetFontSize());

			ImGui.BeginChild("item", (.)DirectoryItemSize, .None, .NoScrollbar);
			
			ImGui.PushStyleColor(.Button, ImGui.Vec4(0, 0, 0, 0));

			// TODO: preview images
			SubTexture2D image = _newFileCreator.Icon ?? s_FileTexture;

			ImGui.ImageButton("FileImage", image, (.)IconSize);

			ImGui.PopStyleColor();

			ImGui.PushItemWidth((.)IconSize.X);

			ImGui.InputText("##newFileNameBox", &_newFileName, _newFileName.Count - 1, .AutoSelectAll);

			ImGui.PopItemWidth();
			
			ImGui.SetKeyboardFocusHere(-1);

			void CreateFile()
			{
				CreateAsset();
			}

			if (ImGui.IsKeyDown(.Escape))
			{
				// Abort
				HideNewFile();
			}
			else if (ImGui.IsItemDeactivatedAfterEdit())
			{
				CreateFile();
			}
			else if (ImGui.IsItemDeactivated())
			{
				// Abort
				HideNewFile();
			}

			ImGui.EndChild();
		}

		private void DrawDeleteItemPopup()
		{
			if (_selectedFiles.IsEmpty)
				return;

			// Always center this window when appearing
			ImGui.Vec2 center = ImGui.GetMainViewport().GetCenter();
			ImGui.SetNextWindowPos(center, .Appearing, ImGui.Vec2(0.5f, 0.5f));

			// TODO: fix delete popup

			if (ImGui.BeginPopupModal("Delete?", null, .AlwaysAutoResize))
			{
				if (_selectedFiles.Count == 1)
				{
					Result<TreeNode<AssetNode>> nodeResult = _manager.AssetHierarchy.GetNodeFromPath(_selectedFiles[0]);
					
					if (nodeResult case .Ok(TreeNode<AssetNode> node))
					{
						ImGui.Text(
							$"""
							Do you really want to delete "{node->Name}"?


							""");
					}
				}
				else
				{
					ImGui.Text(
						$"""
						Do you really want to delete {_selectedFiles.Count} directories/assets?
	
	
						""");
				}


				ImGui.Separator();

				if (ImGui.Button("Yes", ImGui.Vec2(120, 0)))
				{
					List<StringView> paths = scope .();
					for (String path in _selectedFiles)
					{
						paths.Add(path);
					}

					_manager.AssetHierarchy.DeletePathsBackground(paths);

					ImGui.CloseCurrentPopup();
				}

				ImGui.SetItemDefaultFocus();
				ImGui.SameLine();

				if (ImGui.Button("Cancel", ImGui.Vec2(120, 0)))
				{
					ImGui.CloseCurrentPopup();
				}

				ImGui.EndPopup();
			}
		}

		/// Shows the context menu for the given file/folder.
		private void ShowItemContextMenu() //(TreeNode<AssetNode> fileOrFolder, DirectoryItemType itemType, ref bool wantsDelete)
		{
			bool singleEntry = _selectedFiles.Count == 1;

			bool isFile = false;

			List<TreeNode<AssetNode>> entries = new:ScopedAlloc! .(_selectedFiles.Count);

			_selectedFiles.Select((e) => {
				return _manager.AssetHierarchy.GetNodeFromPath(e);
			}).Where((e) => e case .Ok).Select((e) => e.Get()).ToList(entries);

			bool sameParent = entries.Select((e) => e.Parent).Distinct().Count() == 1;

			TreeNode<AssetNode> firstEntry = entries.First();
			TreeNode<AssetNode> parent = sameParent ? entries.First().Parent : null;

			if (singleEntry)
			{
				isFile = !firstEntry->IsDirectory;
			}

		    if ((singleEntry || sameParent) && ImGui.MenuItem("Show in file browser..."))
		    {
				if (singleEntry)
				{
					if (Path.OpenFolderAndSelectItem(firstEntry->Path) case .Err)
					{
						Log.EngineLogger.Error("Failed to show path in file browser.");
					}
				}
				else
				{
					if (Path.OpenFolder(parent->Path) case .Err)
					{
						Log.EngineLogger.Error("Failed to show path in file browser.");
					}
				}
		    }

			if (isFile && ImGui.MenuItem("Open file with..."))
			{
				if (Path.OpenWithDialog(firstEntry->Path) case .Err)
				{
					Log.EngineLogger.Error("Failed to show \"Open with...\" dialog.");
				}
			}
			
			if (singleEntry && ImGui.BeginMenu("Copy path"))
			{
				if (ImGui.MenuItem("Full path"))
				{
					ImGui.SetClipboardText(firstEntry->Path);
				}
				
				ImGui.AttachTooltip(scope $"Copies the full file path of this asset.\n(\"{firstEntry->Path}\")");

				if (ImGui.MenuItem("File name"))
				{
					ImGui.SetClipboardText(firstEntry->Name);
				}

				ImGui.AttachTooltip(scope $"Copies the file name of this asset.\n(\"{firstEntry->Name}\")");

				if (ImGui.MenuItem("Asset identifier"))
				{
					ImGui.SetClipboardText(firstEntry->Identifier.FullIdentifier.Ptr);
				}

				ImGui.AttachTooltip(scope $"Copies the identifier of this asset.\n(\"{firstEntry->Identifier.FullIdentifier}\")");
				
				ImGui.EndMenu();
			}

			/*if (singleEntry && itemType != .ParentDirectory)
			{
				ImGui.Separator();

				if (ImGui.MenuItem("Rename"))
				{
					// Copy the path, just for the rare case that fileOrFolder gets deleted
					_assetToRename.Set(fileOrFolder->Path);

					fileOrFolder->Name.CopyTo(_renameFileNameBuffer);
				}

				if (ImGui.MenuItem("Delete"))
				{
					wantsDelete = true;
				}
			}
*/
			ImGui.Separator();
			
			if (singleEntry && ImGui.MenuItem("Properties..."))
			{
				OpenPropertiesWindow(firstEntry);
			}
		}

		private void OpenPropertiesWindow(TreeNode<AssetNode> fileOrFolder)
		{
			AssetHandle? assetHandle = fileOrFolder->AssetFile?.AssetConfig?.AssetHandle;

			if (assetHandle != null)
			{
				new PropertiesWindow(_editor, .Asset(assetHandle.Value));
			}
		}

		private void OpenEntry(TreeNode<AssetNode> entry)
		{
			if (entry->IsDirectory)
			{
				_directoryHistory.Navigate(entry->Path);
				_selectedFiles.ClearAndDeleteItems();
			}
			else
			{
				// Special treatment for scripts, open them in Visual Studio.
				if (entry->Path.EndsWith(".cs"))
				{
					// Obviously windows only
					RiderIdeAdapter.OpenScript(entry->Path);
				}
				else if (Path.OpenFolder(entry->Path) case .Err)
					Log.EngineLogger.Error("Failed to open file.");
			}
		}

		void DrawNavigationBar()
		{
			ImGui.BeginDisabled(!_directoryHistory.CanGoBack);

			if (ImGui.Button("<"))
			{
				NavigateBack();
			}

			ImGui.AttachTooltip("Back (Alt + Left)");

			ImGui.EndDisabled();

			ImGui.SameLine();

			ImGui.BeginDisabled(!_directoryHistory.CanGoForward);

			if (ImGui.Button(">"))
			{
				NavigateForward();
			}

			ImGui.AttachTooltip("Forward (Alt + Right)");

			ImGui.EndDisabled();

			ImGui.SameLine();

			ImGui.BeginDisabled(!CanNavigateUp);

			if (ImGui.Button("/\\"))
			{
				NavigateUp();
			}

			ImGui.AttachTooltip("Up (Alt + Up)");

			ImGui.EndDisabled();

			List<TreeNode<AssetNode>> path = scope .();

			TreeNode<AssetNode> walker = _currentDirectoryNode;

			repeat
			{
				path.AddFront(walker);
				walker = walker.Parent;
			} while (walker != _manager.AssetHierarchy.RootNode);

			ImGui.SameLine();

			float2 spacing = (.)ImGui.GetStyle().ItemSpacing;
			spacing.X = 0;
			ImGui.PushScopedStyleVar!(ImGui.TypedStyleVar.ItemSpacing(spacing));
			ImGui.PushScopedStyleVar!(ImGui.TypedStyleVar.FrameRounding(0));

			String buttonText = scope .(128);

			for (TreeNode<AssetNode> node in path)
			{
				buttonText.SetF($"{node->Name}##{node->Path}");

				if (ImGui.Button(buttonText) && node != _currentDirectoryNode)
				{
					Navigate(node);
				}

				ImGui.SameLine();

				ImGui.Text("/");

				ImGui.SameLine();
			}

			ImGui.NewLine();
		}
	}
}