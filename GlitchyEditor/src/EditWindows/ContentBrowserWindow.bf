using ImGui;
using System;
using System.IO;
using System.Linq;
using GlitchyEngine.Collections;
using System.Collections;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using GlitchyEngine;
using GlitchyEditor.Assets;

namespace GlitchyEditor.EditWindows
{
	using internal GlitchyEditor.EditorContentManager;

	class AssetCreator
	{
		private String _name ~ delete _;
		private String _defaultFileName ~ delete _;
		private CreateAssetFunc _doCreateAsset ~ delete _;

		public delegate void CreateAssetFunc(StringView outputPath);

		public StringView Name => _name;
		public StringView DefaultFileName => _defaultFileName;

		public CreateAssetFunc CreateAsset => _doCreateAsset;

		public this(StringView name, StringView defaultFileName, CreateAssetFunc createAsset)
		{
			_name = new String(name);
			_defaultFileName = new String(defaultFileName);
			_doCreateAsset = createAsset;
		}
	}

	class ContentBrowserWindow : EditorWindow
	{
		private append List<AssetCreator> _assetCreators = .() ~ ClearAndDeleteItems!(_);

		private typealias AssetCreatorTree = TreeNode<(StringView Name, AssetCreator Creator)>;

		private AssetCreatorTree _creatorTree = new AssetCreatorTree(("Create new Asset", null)) ~ delete _;

		public const String s_WindowTitle = "Content Browser";

		private append String _currentDirectory = .();

		private append String _selectedFile = .();

		public static SubTexture2D s_FolderTexture;
		public static SubTexture2D s_FileTexture;

		public EditorContentManager _manager;

		public StringView SelectedFile => _selectedFile;

		public this(EditorContentManager contentManager)
		{
			_manager = contentManager;
		}

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
		}

		protected override void InternalShow()
		{
			_manager.Update();
			
			// Make sure we are in an existing directory.
			if (!_manager.AssetHierarchy.FileExists(_currentDirectory))
			{
				_currentDirectory.Set(_manager.AssetDirectory);
			}

			if(!ImGui.Begin(s_WindowTitle, &_open, .None))
			{
				ImGui.End();
				return;
			}

			ImGui.PushStyleVar(.CellPadding, .(0, 0));

			bool alt_pressed = ImGui.GetIO().KeyAlt;

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
					DrawCurrentDirectory();

					// Context menu when clicking on the background.
					if (ImGui.BeginPopupContextWindow())
					{
					    ShowCurrentFolderContextMenu();
					    ImGui.EndPopup();
					}

					ImGui.EndChild();
				}

				ImGui.EndTable();
			}

			ImGui.PopStyleVar(1);

			ImGui.End();
		}

		char8[256] _filesFilter = .();
		bool _searchEverywhere;

		private void DrawSearchBar()
		{
			ImGui.TextUnformatted("Search:");
			ImGui.SameLine();
			ImGui.InputText("##search", &_filesFilter, _filesFilter.Count);
			ImGui.SameLine();
			ImGui.Checkbox("Search everywhere", &_searchEverywhere);
		}

		/// Renders the context menu that is shown when the user right clicks on the background of the file browser.
		private void ShowCurrentFolderContextMenu()
		{
			if (ImGui.MenuItem("Open in file browser..."))
			{
				if (Path.OpenFolder(_currentDirectory) case .Err)
					Log.EngineLogger.Error("Failed to open directory in file browser.");
			}

			ImGui.Separator();

			ShowCreateContextMenu(_creatorTree);
		}

		/// Shows the menu for the given asset creator tree.
		private void ShowCreateContextMenu(AssetCreatorTree subtree)
		{
			if (subtree.Children.Count == 0)
			{
				if (ImGui.MenuItem(subtree->Name.ToScopeCStr!()))
				{
					CreateAsset(subtree->Creator);
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

		/// Creates a new asset with the given creator
		private void CreateAsset(AssetCreator creator)
		{
			if (!Directory.Exists(_currentDirectory))
			{
				Log.EngineLogger.Error($"Directory {_currentDirectory} doesn't exist.");
				return;
			}
			
			String currentFile = scope String();
			Path.Combine(currentFile, _currentDirectory, creator.DefaultFileName);
			
			String fileExtension = scope String();
			Path.GetExtension(currentFile, fileExtension);

			StringView fileWithoutExtension = currentFile[0...^(fileExtension.Length + 1)];

			int i = 0;
			while (File.Exists(currentFile))
			{
				i++;
				currentFile.Set(fileWithoutExtension);
				currentFile.AppendF($"({i})");
				currentFile.Append(fileExtension);
			}

			creator.CreateAsset(currentFile);
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

			if (tree->Path == _currentDirectory)
				flags |= .Selected;

			// TODO: this kinda works, but the user should be able to close the directory
			/*if (_manager.AssetHierarchy.GetNodeFromPath(_currentDirectory) case .Ok(let currentTreeNode))
			{
				if (currentTreeNode.IsInSubtree(tree))
					ImGui.SetNextItemOpen(true);
			}*/

			bool isOpen = ImGui.TreeNodeEx(name, flags, $"{name}");

			if (!ImGui.IsItemToggledOpen() && ImGui.IsItemClicked(.Left))
			{
				_currentDirectory.Set(tree->Path);
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

		private static float2 DirectoryItemSize = .(110, 110);

		const float2 padding = .(24, 24);

		/// Renders the contents of _currentDirectory.
		private void DrawCurrentDirectory()
		{
			List<TreeNode<AssetNode>> files = null;
			
			ImGui.Style* style = ImGui.GetStyle();

			float window_visible_x2 = ImGui.GetWindowPos().x + ImGui.GetWindowContentRegionMax().x;

			StringView searchFilter = StringView(&_filesFilter);

			if (_searchEverywhere && searchFilter.Length > 0)
			{
				files = scope:: List<TreeNode<AssetNode>>();
				_manager.AssetHierarchy.[Friend]_assetRootNode.ForEach(scope (node) =>
				{
					if (node->Name.Contains(searchFilter, true))
					{
						files.Add(node);
					}
				});
			}
			else
			{
				if (_currentDirectory.IsEmpty)
					return;

				// Get the node of the current directory.
				var currentDirectoryNode = _manager.AssetHierarchy.GetNodeFromPath(_currentDirectory);
	
				if (currentDirectoryNode case .Err)
				{
					Log.EngineLogger.Error($"No node exists for {_currentDirectory}.");
					ImGui.TextUnformatted("Failed to display contents of directory.");
					return;
				}

				files = currentDirectoryNode->Children;

				// show back button (".."-File)
				if (currentDirectoryNode->Parent != null)
				{
					ImGui.PushID("Back");
	
					DrawBackButton(currentDirectoryNode->Parent);
	
					// X-Coordinate of the right side of the current entry.
					float currentButtonRight = ImGui.GetItemRectMax().x;
					// Expected right-Coordinate if next entry was on the same line.
					float expectedButtonRight = currentButtonRight + style.ItemSpacing.x + DirectoryItemSize.X;
	
					// If the next button won't fit on the same line we start a new line.
					if (expectedButtonRight < window_visible_x2)
					    ImGui.SameLine();
	
					ImGui.PopID();
				}
			}

			for (var entry in files)
			{
				if (!entry->Name.Contains(searchFilter, true))
					continue;

			    ImGui.PushID(entry->Name);

				DrawDirectoryItem(entry);

				// X-Coordinate of the right side of the current entry.
				float currentButtonRight = ImGui.GetItemRectMax().x;
				// Expected right-Coordinate if next entry was on the same line.
				float expectedButtonRight = currentButtonRight + style.ItemSpacing.x + DirectoryItemSize.X;

				// If we aren't the last entry and the next button won't fit on the same line we start a new line.
				if (entry != files.Back && expectedButtonRight < window_visible_x2)
				    ImGui.SameLine();

				ImGui.PopID();
			}
		}
		
		float _zoom = 1.0f;
		static readonly float2 IconBaseSize = .(100, 100);

		float2 IconSize => IconBaseSize * _zoom;

		/// Renders the button for the given directory item.
		private void DrawBackButton(TreeNode<AssetNode> entry)
		{
			ImGui.PushStyleVar(.WindowPadding, .(0, 0));
			ImGui.PushStyleVar(.FramePadding, .(0, 0));
			ImGui.PushStyleVar(.ItemSpacing, .(0, 0));

			defer {ImGui.PopStyleVar(3); }

			float2 DirectoryItemSize = IconSize + (float2)ImGui.GetStyle().WindowPadding * 2 + float2(0, ImGui.GetFontSize());

			ImGui.BeginChild("item", (.)DirectoryItemSize, false, .NoScrollbar);

			if (entry->Path == _selectedFile)
			{
				var color = ImGui.GetStyleColorVec4(.ButtonHovered);
				ImGui.PushStyleColor(.Button, *color);
			}
			else
			{
				ImGui.PushStyleColor(.Button, ImGui.Vec4(0, 0, 0, 0));
			}
			
			SubTexture2D image = s_FolderTexture;

			ImGui.ImageButton("BackFolder", image, (.)IconSize);

			ImGui.PopStyleColor();

			if (ImGui.IsItemHovered() && ImGui.IsMouseClicked(.Left))
			{
				if (_selectedFile != entry->Path)
				{
					_selectedFile.Set(entry->Path);
				}
			}

			if (ImGui.IsItemHovered() && ImGui.IsMouseDoubleClicked(.Left))
			{
				EntryDoubleClicked(entry);
			}

			ImGui.TextUnformatted("..");

			ImGui.EndChild();
		}

		/// Renders the button for the given directory item.
		private void DrawDirectoryItem(TreeNode<AssetNode> entry)
		{
			ImGui.PushStyleVar(.WindowPadding, .(0, 0));
			ImGui.PushStyleVar(.FramePadding, .(0, 0));
			ImGui.PushStyleVar(.ItemSpacing, .(0, 0));

			defer {ImGui.PopStyleVar(3); }

			float2 DirectoryItemSize = IconSize + (float2)ImGui.GetStyle().WindowPadding * 2 + float2(0, ImGui.GetFontSize());

			ImGui.BeginChild("item", (.)DirectoryItemSize, false, .NoScrollbar);

			if (entry->Path == _selectedFile)
			{
				var color = ImGui.GetStyleColorVec4(.ButtonHovered);
				ImGui.PushStyleColor(.Button, *color);
			}
			else
			{
				ImGui.PushStyleColor(.Button, ImGui.Vec4(0, 0, 0, 0));
			}

			// TODO: preview images
			SubTexture2D image = entry->IsDirectory ? s_FolderTexture : s_FileTexture;

			ImGui.ImageButton("FileImage", image, (.)IconSize);

			ImGui.PopStyleColor();

			if (ImGui.BeginDragDropSource())
			{
				ImGui.SetDragDropPayload(.ContentBrowserItem, entry->Identifier, (uint64)entry->Identifier.Length, .Once);

				ImGui.EndDragDropSource();
			}

			if (ImGui.IsItemHovered() && ImGui.IsMouseClicked(.Left))
			{
				if (_selectedFile != entry->Path)
				{
					_selectedFile.Set(entry->Path);
				}
			}

			if (ImGui.IsItemHovered() && ImGui.IsMouseDoubleClicked(.Left))
			{
				EntryDoubleClicked(entry);
			}

			ImGui.TextUnformatted(entry->Name);

			bool wantsDelete = false;

			if (ImGui.BeginPopupContextWindow())
			{
			    ShowItemContextMenu(entry, ref wantsDelete);
			    ImGui.EndPopup();
			}

			if (wantsDelete)
            	ImGui.OpenPopup("Delete?");

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

			DeleteItemPopup(entry);

			ImGui.EndChild();

			ImGui.AttachTooltip(entry->Name);
		}

		private void DeleteItemPopup(TreeNode<AssetNode> fileOrFolder)
		{
			// Always center this window when appearing
			ImGui.Vec2 center = ImGui.GetMainViewport().GetCenter();
			ImGui.SetNextWindowPos(center, .Appearing, ImGui.Vec2(0.5f, 0.5f));

			// TODO: fix delete popup

			if (ImGui.BeginPopupModal("Delete?", null, .AlwaysAutoResize))
			{
				ImGui.Text($"""
					Delete "{fileOrFolder->Name}"?


					""");

				ImGui.Separator();

				if (ImGui.Button("Yes", ImGui.Vec2(120, 0)))
				{
					_manager.AssetHierarchy.DeleteFile(fileOrFolder.Value);

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
		private void ShowItemContextMenu(TreeNode<AssetNode> fileOrFolder, ref bool wantsDelete)
		{
			bool isFile = !fileOrFolder->IsDirectory;

		    if (ImGui.MenuItem("Show in file browser..."))
		    {
				if (Path.OpenFolderAndSelectItem(fileOrFolder->Path) case .Err)
				{
					Log.EngineLogger.Error("Failed to show path in file browser.");
				}
		    }

			if (isFile && ImGui.MenuItem("Open file with..."))
			{
				if (Path.OpenWithDialog(fileOrFolder->Path) case .Err)
				{
					Log.EngineLogger.Error("Failed to show \"Open with...\" dialog.");
				}
			}

			if (ImGui.MenuItem("Delete"))
			{
				wantsDelete = true;
			}
		}

		private void EntryDoubleClicked(TreeNode<AssetNode> entry)
		{
			if (entry->IsDirectory)
			{
				_currentDirectory.Set(entry->Path);
			}
			else
			{
				if (Path.OpenFolder(entry->Path) case .Err)
					Log.EngineLogger.Error("Failed to open directory in file browser.");
			}
		}
	}
}