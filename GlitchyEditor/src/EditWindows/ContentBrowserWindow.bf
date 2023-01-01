using ImGui;
using System;
using System.IO;
using GlitchyEngine.Collections;
using System.Collections;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;

namespace GlitchyEditor.EditWindows
{
	using internal GlitchyEditor.EditorContentManager;

	class ContentBrowserWindow : EditorWindow
	{
		// TODO: Get from project
		const String ContentDirectory  = "./content";

		//private String _currentDirectory ~ delete _;
		private TreeNode<AssetNode> _currentDirectoryNode;

		public static SubTexture2D s_FolderTexture;
		public static SubTexture2D s_FileTexture;

		public EditorContentManager _manager;

		public this(EditorContentManager contentManager)
		{
			_manager = contentManager;
		}

		protected override void InternalShow()
		{
			_manager.Update();

			_currentDirectoryNode ??= _manager._assetHierarchy;

			if(!ImGui.Begin("Content Browser", &_open, .None))
			{
				ImGui.End();
				return;
			}

			ImGui.Columns(2);

			DrawDirectorySideBar();

			ImGui.NextColumn();

			DrawCurrentDirectory();

			ImGui.Columns(1);

			ImGui.End();
		}

		private void DrawDirectorySideBar()
		{
			for(var child in _manager._assetHierarchy.Children)
			{
				ImGuiPrintEntityTree(child);
			}
		}

		private void ImGuiPrintEntityTree(TreeNode<AssetNode> tree)
		{
			if (!tree->IsDirectory)
				return;

			String name = tree->Name;

			ImGui.TreeNodeFlags flags = .OpenOnArrow | .SpanAvailWidth;

			if(tree.Children.Count == 0)
				flags |= .Leaf;

			if (tree == _currentDirectoryNode)
			{
				flags |= .Selected;
			}

			bool isOpen = ImGui.TreeNodeEx(name, flags, $"{name}");

			if (ImGui.IsItemClicked(.Left))
			{
				/*if (_currentDirectory != null)
					delete _currentDirectory;

				_currentDirectory = new String(tree.Value.Path);*/
				_currentDirectoryNode = tree;
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

		private static Vector2 DirectoryItemSize = .(110, 110);

		const Vector2 padding = .(24, 24);

		private void DrawCurrentDirectory()
		{
			if (_currentDirectoryNode == null)
				return;

			ImGui.Style* style = ImGui.GetStyle();

			float window_visible_x2 = ImGui.GetWindowPos().x + ImGui.GetWindowContentRegionMax().x;
			for (var entry in _currentDirectoryNode.Children)
			{
			    ImGui.PushID(entry->Name);

				DrawDirectoryItem(entry);
				
				float last_button_x2 = ImGui.GetItemRectMax().x;
				float next_button_x2 = last_button_x2 + style.ItemSpacing.x + DirectoryItemSize.X; // Expected position if next button was on same line
				if (entry != _currentDirectoryNode.Children.Back && next_button_x2 < window_visible_x2)
				    ImGui.SameLine();

				ImGui.PopID();
			}
		}

		private void DrawDirectoryItem(TreeNode<AssetNode> entry)
		{
			ImGui.BeginChild("item", (.)DirectoryItemSize);

			SubTexture2D image = entry->IsDirectory ? s_FolderTexture : s_FileTexture;

			ImGui.PushStyleColor(.Button, ImGui.Vec4(0, 0, 0, 0));

			ImGui.ImageButton(image, (.)(DirectoryItemSize - padding));

			if (ImGui.BeginDragDropSource())
			{
				String fullpath = scope $"{_currentDirectoryNode->Path}{Path.DirectorySeparatorChar}{entry->Name}";

				// TODO: this is dirty
				if (fullpath.StartsWith(ContentDirectory, .OrdinalIgnoreCase))
					fullpath.Remove(0, ContentDirectory.Length);

				ImGui.SetDragDropPayload("CONTENT_BROWSER_ITEM", fullpath.CStr(), (.)fullpath.Length, .Once);

				ImGui.EndDragDropSource();
			}

			if (ImGui.IsItemHovered() && ImGui.IsMouseDoubleClicked(.Left))
			{
				EntryDoubleClicked(entry);
			}

			ImGui.PopStyleColor();

			ImGui.TextUnformatted(entry->Name);

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
						String fullpath = Path.InternalCombine(.. scope String(), _currentDirectoryNode->Path, entry->Name);
						fullpath.AppendF($"#{subAsset.Name}");
							//scope $"{_currentDirectoryNode->Path}{Path.DirectorySeparatorChar}{entry->Name}";
						//String fullpath = scope $"{subAsset.Asset.Path}#{subAsset.Name}";

						// TODO: this is dirty
						//if (fullpath.StartsWith(ContentDirectory, .OrdinalIgnoreCase))
						//	fullpath.Remove(0, ContentDirectory.Length);
		
						ImGui.SetDragDropPayload("CONTENT_BROWSER_ITEM", fullpath.CStr(), (.)fullpath.Length, .Once);
		
						ImGui.EndDragDropSource();
					}
				}

				ImGui.EndPopup();
			}
			
			ImGui.EndChild();
		}

		private void EntryDoubleClicked(TreeNode<AssetNode> entry)
		{
			if (entry->IsDirectory)
			{
				_currentDirectoryNode = entry;
			}
		}
	}
}