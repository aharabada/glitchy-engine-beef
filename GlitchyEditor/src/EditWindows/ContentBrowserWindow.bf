using ImGui;
using System;
using System.IO;
using GlitchyEngine.Collections;
using System.Collections;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using GlitchyEngine;
using GlitchyEditor.Assets;

namespace GlitchyEditor.EditWindows
{
	using internal GlitchyEditor.EditorContentManager;

	class ContentBrowserWindow : EditorWindow
	{
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

		protected override void InternalShow()
		{
			_manager.Update();
			
			// Make sure we are in an existing directory.
			if (!_manager.AssetHierarchy.FileExists(_currentDirectory))
			{
				_currentDirectory.Set(_manager.ContentDirectory);
			}

			if(!ImGui.Begin(s_WindowTitle, &_open, .None))
			{
				ImGui.End();
				return;
			}

			ImGui.Columns(2);

			ImGui.BeginChild("Sidebar");

			DrawDirectorySideBar();

			ImGui.EndChild();

			ImGui.NextColumn();

			ImGui.BeginChild("Files");

			DrawCurrentDirectory();
			
			// Context menu when clicking on the background.
			if (ImGui.BeginPopupContextWindow())
			{
			    ShowCurrentFolderContextMenu();
			    ImGui.EndPopup();
			}

			ImGui.EndChild();

			ImGui.Columns(1);

			ImGui.End();
		}

		/// Renders the context menu that is shown when the user right clicks on the background of the file browser.
		private void ShowCurrentFolderContextMenu()
		{
			if (ImGui.MenuItem("Open in file browser..."))
			{
				if (Path.OpenFolder(_currentDirectory) case .Err)
					Log.EngineLogger.Error("Failed to open directory in file browser.");
			}
		}

		/// Renders a sidebar that shows a tree of all directories in the asset folder.
		private void DrawDirectorySideBar()
		{
			for(var child in _manager.AssetHierarchy.[Friend]_assetHierarchy.Children)
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

			if(tree.Children.Count == 0)
				flags |= .Leaf;

			if (tree->Path == _currentDirectory)
			{
				flags |= .Selected;
			}

			bool isOpen = ImGui.TreeNodeEx(name, flags, $"{name}");

			if (ImGui.IsItemClicked(.Left))
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
			if (_currentDirectory.IsEmpty)
				return;

			ImGui.Style* style = ImGui.GetStyle();

			float window_visible_x2 = ImGui.GetWindowPos().x + ImGui.GetWindowContentRegionMax().x;

			// Get the node of the current directory.
			var currentDirectoryNode = _manager.AssetHierarchy.GetNodeFromPath(_currentDirectory);

			if (currentDirectoryNode case .Err)
			{
				Log.EngineLogger.Error($"No node exists for {_currentDirectory}.");
				ImGui.TextUnformatted("Failed to display contents of directory.");
				return;
			}

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

			for (var entry in currentDirectoryNode->Children)
			{
			    ImGui.PushID(entry->Name);

				DrawDirectoryItem(entry);

				// X-Coordinate of the right side of the current entry.
				float currentButtonRight = ImGui.GetItemRectMax().x;
				// Expected right-Coordinate if next entry was on the same line.
				float expectedButtonRight = currentButtonRight + style.ItemSpacing.x + DirectoryItemSize.X;

				// If we aren't the last entry and the next button won't fit on the same line we start a new line.
				if (entry != currentDirectoryNode->Children.Back && expectedButtonRight < window_visible_x2)
				    ImGui.SameLine();

				ImGui.PopID();
			}
		}

		/// Renders the button for the given directory item.
		private void DrawBackButton(TreeNode<AssetNode> entry)
		{
			ImGui.BeginChild("item", (.)DirectoryItemSize);

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

			ImGui.ImageButton(image, (.)(DirectoryItemSize - padding));

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
			ImGui.BeginChild("item", (.)DirectoryItemSize);

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

			ImGui.ImageButton(image, (.)(DirectoryItemSize - padding));

			ImGui.PopStyleColor();

			if (ImGui.BeginDragDropSource())
			{
				String fullpath = scope String(entry->Path);

				// TODO: this is dirty
				if (fullpath.StartsWith(_manager.ContentDirectory, .OrdinalIgnoreCase))
					fullpath.Remove(0, _manager.ContentDirectory.Length);

				Path.Fixup(fullpath);

				ImGui.SetDragDropPayload("CONTENT_BROWSER_ITEM", fullpath.CStr(), (.)fullpath.Length, .Once);

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

			if (ImGui.BeginPopupContextWindow())
			{
			    ShowItemContextMenu(entry);
			    ImGui.EndPopup();
			}

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

						ImGui.SetDragDropPayload("CONTENT_BROWSER_ITEM", fullpath.CStr(), (.)fullpath.Length, .Once);
		
						ImGui.EndDragDropSource();
					}
				}

				ImGui.EndPopup();
			}

			DeleteItemPopup(entry);
			
			ImGui.EndChild();
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
		private void ShowItemContextMenu(TreeNode<AssetNode> fileOrFolder)
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
            	ImGui.OpenPopup("Delete?");
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