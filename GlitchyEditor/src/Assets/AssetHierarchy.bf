using GlitchyEngine;
using GlitchyEngine.Collections;
using GlitchyEngine.Renderer;
using System;
using System.Collections;
using System.IO;
using System.Linq;

namespace GlitchyEditor.Assets;

public class AssetNode
{
	public String Name ~ delete _;
	public String Path ~ delete _;

	public bool IsDirectory;

	public AssetFile AssetFile ~ delete _;

	public List<SubAsset> SubAssets ~ {
		SubAssets?.ClearAndDeleteItems();
		delete SubAssets;
	}

	public Texture2D PreviewImage ~ _?.ReleaseRef();
}

public class SubAsset
{
	public AssetNode Asset;
	public String Name ~ delete _;
	//public String AssetInternalPath ~ delete _;

	public Texture2D PreviewImage ~ _?.ReleaseRef();
}

public static class AssetIdentifier
{
	public const char8 DirectorySeparatorChar = '/';

	public static void Fixup(String assetIdentifier)
	{
		const String DotSeperator = $".{DirectorySeparatorChar}";
		const String SeperatorDot = $"{DirectorySeparatorChar}.";

		assetIdentifier.Replace('\\', DirectorySeparatorChar);
		assetIdentifier.Replace(DotSeperator, "");
		assetIdentifier.Replace(SeperatorDot, "");

		if (assetIdentifier.StartsWith(DirectorySeparatorChar))
			assetIdentifier.Remove(0, 1);
	}
}

class AssetHierarchy
{
	FileSystemWatcher fsw ~ {
		_.StopRaisingEvents();
		delete _;
	};
	
	bool _fileSystemDirty = false;
	
	internal TreeNode<AssetNode> _assetHierarchy = null ~ DeleteTreeAndChildren!(_);
	private append Dictionary<StringView, TreeNode<AssetNode>> _pathToAssetNode = .();
	
	private append String _contentDirectory = .();

	private EditorContentManager _contentManager;

	public StringView ContentDirectory
	{
		get => _contentDirectory;
		private set
		{
			_contentDirectory.Clear();
			_contentDirectory.Append(value);
			Path.Fixup(_contentDirectory);
		}
	}

	public this(EditorContentManager contentManager)
	{
		_contentManager = contentManager;
	}

	public void SetContentDirectory(StringView contentDirectory)
	{
		ContentDirectory = contentDirectory;

		_fileSystemDirty = true;

		SetupFileSystemWatcher();

		Update();
	}
	
	/// Initializes the FSW for the current ContentDirectory and registers the events.
	private void SetupFileSystemWatcher()
	{
		delete fsw;
		fsw = new FileSystemWatcher(_contentDirectory);
		fsw.IncludeSubdirectories = true;

		fsw.OnChanged.Add(new (filename) => {
			// Note: Gets fired for a directory if a file inside it is created/removed
			
			Log.EngineLogger.Trace($"File content changed (\"{filename}\")");
			//_fileSystemDirty = true;

			FileContentChanged(filename);
		});

		fsw.OnCreated.Add(new (filename) => {
			Log.EngineLogger.Trace($"File created (\"{filename}\")");

			_fileSystemDirty = true;
		});

		fsw.OnDeleted.Add(new (filename) => {
			Log.EngineLogger.Trace($"File deleted (\"{filename}\")");

			_fileSystemDirty = true;
		});

		fsw.OnRenamed.Add(new (oldName, newName) => {
			Log.EngineLogger.Trace($"File renamed (From \"{oldName}\" to \"{newName}\")");
			
			//_fileSystemDirty = true;
			FileRenamed(oldName, newName);
			/*String contentFilePath = scope String();

			Path.InternalCombine(contentFilePath, ContentDirectory, oldName);

			//_fileSystemDirty = true;
			TreeNode<AssetNode> fileNode = GetNodeFromPath(contentFilePath);
			fileNode->*/
		});

		fsw.StartRaisingEvents();
	}

	/// Gets the tree node for the given filePath or .Err, if the file/directory doesn't exist.
	/// @param filePath the path for which to return the tree node.
	/// @remarks Do not hold a reference to the TreeNode because it can become invalid when the file hierarchy changes.
	public Result<TreeNode<AssetNode>> GetNodeFromPath(StringView filePath)
	{
		if (_pathToAssetNode.TryGetValue(filePath, let treeNode))
		{
			return treeNode;
		}

		return .Err;
	}

	public bool FileExists(StringView filePath)
	{
		return _pathToAssetNode.ContainsKey(filePath);
	}

	public void Update()
	{
		// TODO: do we really need to do this in the update loop?
		if (_fileSystemDirty)
		{
			UpdateFiles();
		}
	}
	

	/// Rebuilds the asset file hierarchy.
	private void UpdateFiles()
	{
		Log.EngineLogger.Trace($"Updating asset hierarchy");

		if (_assetHierarchy == null)
		{
			// TODO: move to init?

			_assetHierarchy = new TreeNode<AssetNode>(new AssetNode());
			_assetHierarchy->Path = new String(ContentDirectory);
			_assetHierarchy->Name = new String("Content");
			_assetHierarchy->IsDirectory = true;

			Log.EngineLogger.Trace($"Created directory node for: \"{_assetHierarchy->Path}\"");

			_pathToAssetNode.Add(ContentDirectory, _assetHierarchy);
		}

		void HandleFile(AssetNode node)
		{
			String identifier = scope .(node.Path.Length);
			Path.GetRelativePath(node.Path, _contentDirectory, identifier);
			AssetIdentifier.Fixup(identifier);

			node.AssetFile = new AssetFile(_contentManager, identifier, node.Path, node.IsDirectory);
		}

		/// Determines the files that belong to the given directory and adds them to the tree.
		void AddFilesOfDirectory(TreeNode<AssetNode> directory)
		{
			// Filter that accepts all files.
			String filter = scope $"{directory->Path}/*";

			// Buffer used to hold the path of the files iterated below.
			String filepathBuffer = scope String(256);
			// Buffer used to hold the file extension of the files iterated below.
			String extensionBuffer = scope String(16);

			for (var entry in Directory.Enumerate(filter, .Files))
			{
				entry.GetFilePath(filepathBuffer..Clear());

				Path.GetExtension(filepathBuffer, .. extensionBuffer..Clear());

				// Ignore meta files.
				if (extensionBuffer.Equals(AssetFile.ConfigFileExtension, .OrdinalIgnoreCase))
					continue;

				TreeNode<AssetNode> treeNode = directory.Children.Where(scope (node) => node.Value.Path == filepathBuffer).FirstOrDefault();

				if (treeNode == null)
				{
					AssetNode assetNode = new AssetNode();
					assetNode.Name = new String();
					Path.GetFileName(filepathBuffer, assetNode.Name);
					
					filepathBuffer.Replace(Path.AltDirectorySeparatorChar, Path.DirectorySeparatorChar);

					assetNode.Path = new String(filepathBuffer);
					assetNode.IsDirectory = false;

					treeNode = directory.AddChild(assetNode);
					_pathToAssetNode.Add(assetNode.Path, treeNode);

					//GrabSubAssets(node);
					HandleFile(treeNode.Value);

					Log.EngineLogger.Trace($"Created file node for: \"{assetNode.Path}\"");
				}
			}
		}

		void RemoveOrphanedEntries(TreeNode<AssetNode> node)
		{
			/// Removes the node and its children from _pathToAssetNode
			void RemoveSubtree(TreeNode<AssetNode> tree)
			{
				_pathToAssetNode.Remove(tree->Path);

				for (var child in tree.Children)
				{
					RemoveSubtree(child);
				}
			}

			for (TreeNode<AssetNode> child in node.Children)
			{
				if (!Directory.Exists(child->Path) && !File.Exists(child->Path))
				{
					Log.EngineLogger.Trace($"Removed orphaned node for: \"{child->Path}\"");

					@child.Remove();

					RemoveSubtree(child);

					DeleteTreeAndChildren!(child);
				}
			}
		}
		
		/// Adds the given directory to the specified tree.
		/// Recursively adds all Files and Subdirectories.
		void AddDirectoryToTree(String path, TreeNode<AssetNode> parentNode)
		{
			path.Replace(Path.AltDirectorySeparatorChar, Path.DirectorySeparatorChar);

			// Try to find the node for the specified path in the given parent
			TreeNode<AssetNode> treeNode = parentNode.Children.Where(scope (node) => node.Value.Path == path).FirstOrDefault();

			// Create new Node for the Directory, if no TreeNode exists.
			if (treeNode == null)
			{
				AssetNode assetNode = new AssetNode();
				assetNode.Path = new String(path);
				assetNode.Name = new String();
				assetNode.IsDirectory = true;
				Path.GetFileName(assetNode.Path, assetNode.Name);

				treeNode = parentNode.AddChild(assetNode);
				_pathToAssetNode.Add(assetNode.Path, treeNode);

				Log.EngineLogger.Trace($"Created directory node for: \"{assetNode.Path}\"");
			}

			String directoryNameBuffer = scope String(256);

			// Filter that finds all entries of a directory.
			String filter = scope $"{path}/*";

			for (var directory in Directory.Enumerate(filter, .Directories))
			{
				directory.GetFilePath(directoryNameBuffer..Clear());

				AddDirectoryToTree(directoryNameBuffer, treeNode);
			}

			AddFilesOfDirectory(treeNode);

			RemoveOrphanedEntries(treeNode);
		}
		
		String filter = scope $"{ContentDirectory}/*";
		
		String directoryNameBuffer = scope String(256);

		for (var directory in Directory.Enumerate(filter, .Directories))
		{
			directory.GetFilePath(directoryNameBuffer..Clear());

			AddDirectoryToTree(directoryNameBuffer, _assetHierarchy);
		}
		
		RemoveOrphanedEntries(_assetHierarchy);

		_fileSystemDirty = false;
	}

	private void FileContentChanged(StringView fileName)
	{
		var fileName;

		// Config files aren't really tracked but changing them effectively changes the corresponding file
		// so we fire the event for them.
		if (fileName.EndsWith(AssetFile.ConfigFileExtension))
			fileName.RemoveFromEnd(AssetFile.ConfigFileExtension.Length);

		String fileNameWithContentRoot = scope .();
		Path.InternalCombine(fileNameWithContentRoot, _contentDirectory, fileName);

		var nodeResult = GetNodeFromPath(fileNameWithContentRoot);

		TreeNode<AssetNode> node = null;

		if (!(nodeResult case .Ok(out node)))
		{
			// This happens, when we create new files.
			Log.EngineLogger.Trace($"Could not find node for file \"{fileNameWithContentRoot}\"");
			return;
		}

		// Don't fire event for directories.
		if (node->IsDirectory)
			return;

		OnFileContentChanged(node.Value);
	}

	private void FileRenamed(StringView oldFilePath, StringView newFilePath)
	{
		var oldFilePath;

		// Ignore Config files.
		if (oldFilePath.EndsWith(AssetFile.ConfigFileExtension))
			return;


		String oldFileNameWithContentRoot = scope .();
		Path.InternalCombine(oldFileNameWithContentRoot, _contentDirectory, oldFilePath);
		
		String newFileNameWithContentRoot = scope .();
		Path.InternalCombine(newFileNameWithContentRoot, _contentDirectory, newFilePath);
		
		// Rename config file
		{
			String oldConfigFileName = scope $"{oldFileNameWithContentRoot}{AssetFile.ConfigFileExtension}";
			String newConfigFileName = scope $"{newFileNameWithContentRoot}{AssetFile.ConfigFileExtension}";

			if (File.Exists(oldConfigFileName) && !File.Exists(newConfigFileName))
			{
				if (File.Move(oldConfigFileName, newConfigFileName) case .Err(let value))
				{
					Log.EngineLogger.Error($"Failed to move file {oldConfigFileName} to {newConfigFileName}. Code: {value}");
				}
			}
		}

		var nodeResult = GetNodeFromPath(oldFileNameWithContentRoot);

		TreeNode<AssetNode> node = null;

		if (!(nodeResult case .Ok(out node)))
		{
			// This happens, when we create new files.
			Log.EngineLogger.Trace($"Could not find node for file \"{oldFileNameWithContentRoot}\"");
			return;
		}
		
		_pathToAssetNode.Remove(oldFileNameWithContentRoot);

		node->Path.Set(newFileNameWithContentRoot);
		_pathToAssetNode.Add(node->Path, node);
		
		node->Name.Clear();
		Path.GetFileName(newFileNameWithContentRoot, node->Name);

		String oldIdentifier = scope .(node->AssetFile.[Friend]_identifier);

		node->AssetFile.[Friend]_path.Set(node->Path);

		node->AssetFile.[Friend]_identifier.Set(newFilePath);
		AssetIdentifier.Fixup(node->AssetFile.[Friend]_identifier);

		node->AssetFile.[Friend]_assetConfigPath..Set(node->Path).Append(AssetFile.ConfigFileExtension);

		OnFileRenamed(node.Value, oldIdentifier);
	}

	public delegate void FileContentChangedFunc(AssetNode node);

	public Event<FileContentChangedFunc> OnFileContentChanged ~ _.Dispose();

	public delegate void FileRenamedFunc(AssetNode node, StringView oldName);

	public Event<FileRenamedFunc> OnFileRenamed ~ _.Dispose();
}
