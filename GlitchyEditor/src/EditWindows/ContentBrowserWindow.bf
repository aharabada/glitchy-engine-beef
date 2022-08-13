using ImGui;
using System;
using System.IO;
using GlitchyEngine.Collections;
using System.Collections;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;

namespace GlitchyEditor.EditWindows
{
	class ContentBrowserWindow : EditorWindow
	{
		// TODO: Get from project
		const String ContentDirectory  = "./content";

		FileSystemWatcher fsw ~ {
			_.StopRaisingEvents();
			delete _;
		};

		private String _currentDirectory ~ delete _;

		public static SubTexture2D s_FolderTexture;
		public static SubTexture2D s_FileTexture;

		public this()
		{
			fsw = new FileSystemWatcher(ContentDirectory);
			fsw.IncludeSubdirectories = true;

			fsw.OnChanged.Add(new (filename) => {
				_fileSystemDirty = true;
				_currentDirectoryDirty = true;
			});
			
			fsw.OnCreated.Add(new (filename) => {
				_fileSystemDirty = true;
				_currentDirectoryDirty = true;
			});
			
			fsw.OnDeleted.Add(new (filename) => {
				_fileSystemDirty = true;
				_currentDirectoryDirty = true;
			});
			
			fsw.OnRenamed.Add(new (newName, oldName) => {
				_fileSystemDirty = true;
				_currentDirectoryDirty = true;
			});

			fsw.StartRaisingEvents();

		}

		protected override void InternalShow()
		{
			if(!ImGui.Begin("Content Browser", &_open, .None))
			{
				ImGui.End();
				return;
			}

			if (_fileSystemDirty)
			{
				BuildDirectoryTree();

				_fileSystemDirty = false;
			}

			if (_currentDirectoryDirty)
			{
				BuildCurrentDirectory();
			}

			ImGui.Columns(2);

			DrawDirectorySideBar();

			ImGui.NextColumn();

			DrawCurrentDirectory();

			ImGui.Columns(1);

			ImGui.End();
		}

		private bool _fileSystemDirty = true;
		private bool _currentDirectoryDirty = true;

		class DirectoryNode
		{
			public String Name ~ delete _;
			public String Path ~ delete _;
		}

		TreeNode<DirectoryNode> directoryNames = new TreeNode<DirectoryNode>() ~ DeleteTreeAndChildren!(_);

		class Entry
		{
			public String Name ~ delete _;
			public bool IsDirectory;
		}

		List<Entry> _currentDirContent = new .() ~ DeleteContainerAndItems!(_);

		private void BuildDirectoryTree()
		{
			DeleteTreeAndChildren!(directoryNames);
			directoryNames = new TreeNode<DirectoryNode>();
			
			String str = scope .(ContentDirectory);

			void AddDirectoryToTree(String path, TreeNode<DirectoryNode> parentNode)
			{
				DirectoryNode node = new DirectoryNode();
				node.Path = new String(path);
				node.Name = new String();

				Path.GetFileName(node.Path, node.Name);

				var newNode = parentNode.AddChild(node);

				String filter = scope $"{path}/*";

				for (var directory in Directory.Enumerate(filter, .Directories))
				{
					directory.GetFilePath(str..Clear());

					AddDirectoryToTree(str, newNode);
				}
			}
			
			String filter = scope $"{ContentDirectory}/*";

			for (var directory in Directory.Enumerate(filter, .Directories))
			{
				directory.GetFilePath(str..Clear());

				AddDirectoryToTree(str, directoryNames);
			}
		}

		private void BuildCurrentDirectory()
		{
			ClearAndDeleteItems!(_currentDirContent);
			
			String filter = scope $"{_currentDirectory}/*";

			String buffer = scope String();

			for (var entry in Directory.Enumerate(filter, .Directories | .Files))
			{
				entry.GetFilePath(buffer..Clear());

				Entry e = new Entry();
				e.Name = new String();
				Path.GetFileName(buffer, e.Name);
				e.IsDirectory = entry.IsDirectory;

				_currentDirContent.Add(e);
			}
		}

		private void DrawDirectorySideBar()
		{
			for(var child in directoryNames.Children)
			{
				ImGuiPrintEntityTree(child);
			}
		}

		private void ImGuiPrintEntityTree(TreeNode<DirectoryNode> tree)
		{
			String name = tree.Value.Name;

			ImGui.TreeNodeFlags flags = .OpenOnArrow | .SpanAvailWidth;

			if(tree.Children.Count == 0)
				flags |= .Leaf;

			if (tree.Value.Path == _currentDirectory)
			{
				flags |= .Selected;
			}

			bool isOpen = ImGui.TreeNodeEx(name, flags, $"{name}");

			if (ImGui.IsItemClicked(.Left))
			{
				if (_currentDirectory != null)
					delete _currentDirectory;

				_currentDirectory = new String(tree.Value.Path);
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

		private static Vector2 DirectoryItemSize = .(100, 100);

		const Vector2 padding = .(24, 24);

		private void DrawCurrentDirectory()
		{
			ImGui.Style* style = ImGui.GetStyle();

			float window_visible_x2 = ImGui.GetWindowPos().x + ImGui.GetWindowContentRegionMax().x;
			for (var entry in _currentDirContent)
			{
			    ImGui.PushID(entry.Name);

				DrawDirectoryItem(entry);
				
				float last_button_x2 = ImGui.GetItemRectMax().x;
				float next_button_x2 = last_button_x2 + style.ItemSpacing.x + DirectoryItemSize.X; // Expected position if next button was on same line
				if (entry != _currentDirContent.Back && next_button_x2 < window_visible_x2)
				    ImGui.SameLine();

				ImGui.PopID();
			}
		}

		private void DrawDirectoryItem(Entry entry)
		{
			ImGui.BeginChild("item", (.)DirectoryItemSize);

			SubTexture2D image = entry.IsDirectory ? s_FolderTexture : s_FileTexture;

			ImGui.PushStyleColor(.Button, ImGui.Vec4(0, 0, 0, 0));

			ImGui.ImageButton(image, (.)(DirectoryItemSize - padding));

			if (ImGui.BeginDragDropSource())
			{
				String fullpath = scope $"{_currentDirectory}{Path.DirectorySeparatorChar}{entry.Name}";

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

			ImGui.TextUnformatted(entry.Name);
			
			ImGui.EndChild();
		}

		private void EntryDoubleClicked(Entry entry)
		{
			if (entry.IsDirectory)
			{
				_currentDirectory.Append(Path.DirectorySeparatorChar);
				_currentDirectory.Append(entry.Name);
			}
		}
	}
}