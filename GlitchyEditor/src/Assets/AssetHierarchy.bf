using GlitchyEngine;
using GlitchyEngine.Collections;
using GlitchyEngine.Renderer;
using System;
using System.Collections;
using System.IO;
using System.Linq;
using GlitchyEngine.Content;

namespace GlitchyEditor.Assets;

public class AssetNode
{
	public String Name ~ delete _;
	public String Path ~ delete _;
	public String Identifier ~ delete _;

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

	// TODO: Asset identifiers and paths have little to do with each other and already caused a bit of pain, we should consider not using String for both.
	/// Removes or unifies potential platform specific or file-path related stuff in the given asset identifier
	public static void Fixup(String assetIdentifier)
	{
		int dotIndex = 0;

		assetIdentifier.Replace('\\', DirectorySeparatorChar);
		
		// Replace /./ stuff
		while ((dotIndex = assetIdentifier.IndexOf('.', dotIndex)) != -1)
		{
			char8 lastChar = '\0';
			char8 nextChar = '\0';

			int nextIndex = dotIndex + 1;
			if (nextIndex < assetIdentifier.Length)
				nextChar = assetIdentifier[nextIndex];

			int lastIndex = dotIndex - 1;
			if (lastIndex < assetIdentifier.Length)
				lastChar = assetIdentifier[nextIndex];

			// We either need to have a slash on both sides, or we have to be at the start or end of the string
			if ((lastChar == '\0' || lastChar == DirectorySeparatorChar) &&
				(lastChar == '\0' || lastChar == DirectorySeparatorChar))
			{
				if (lastChar != '\0')
					assetIdentifier.Remove(lastIndex, 2);
				else
					assetIdentifier.Remove(dotIndex, 2);
			}
			else
			{
				// Skip the dot
				dotIndex++;
			}
		}

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
	
	internal TreeNode<AssetNode> _assetRootNode = null ~ DeleteTreeAndChildren!(_);
	internal TreeNode<AssetNode> _resourcesDirectoryNode = null;
	internal TreeNode<AssetNode> _assetsDirectoryNode = null;
	private append Dictionary<StringView, TreeNode<AssetNode>> _pathToAssetNode = .();
	private append Dictionary<StringView, TreeNode<AssetNode>> _identifierToAssetNode = .();
	private append Dictionary<AssetHandle, TreeNode<AssetNode>> _handleToAssetNode = .();
	
	private append String _resourcesDirectory = .();
	private append String _assetsDirectory = .();

	private EditorContentManager _contentManager;

	public TreeNode<AssetNode> RootNode => _assetRootNode;

	public StringView ResourcesDirectory
	{
		get => _resourcesDirectory;
		private set
		{
			_resourcesDirectory.Set(value);
			Path.Fixup(_resourcesDirectory);
		}
	}

	public StringView AssetsDirectory
	{
		get => _assetsDirectory;
		private set
		{
			_assetsDirectory.Set(value);
			Path.Fixup(_assetsDirectory);
		}
	}

	public this(EditorContentManager contentManager)
	{
		_contentManager = contentManager;

		// Create a root node that will contain all Asset directory nodes.
		_assetRootNode = new TreeNode<AssetNode>(new AssetNode());
		_assetRootNode->Path = new String();
		_assetRootNode->Name = new String();
		_assetRootNode->IsDirectory = true;

		Log.EngineLogger.Trace($"Created root node");
	}

	/// Deletes the file that belongs to the given assetNode
	public void DeleteFile(AssetNode assetNode)
	{
		if (assetNode.IsDirectory)
		{
			if (Directory.DelTree(assetNode.Path) case .Err(let error))
			{
				Log.EngineLogger.Error($"Couldn't delete Directory ({error}).");
			}
		}
		else
		{
			if (File.Delete(assetNode.Path) case .Err(let error))
			{
				Log.EngineLogger.Error($"Couldn't delete File \"{assetNode.Path}\" ({error}).");
			}
		}

		StringView assetDescriptorPath = assetNode.AssetFile?.FilePath ?? "";

		// If it exists, also try to delete the .ass file
		if (File.Exists(assetDescriptorPath))
		{
			if (File.Delete(assetDescriptorPath) case .Err(let error))
			{
				Log.EngineLogger.Error($"Couldn't delete Asset descriptor file \"{assetDescriptorPath}\" ({error}).");
			}
		}
	}
	
	/// Sets path to the directory that contains the engine assets.
	public void SetResourcesDirectory(StringView fileName)
	{
		ResourcesDirectory = fileName;

		_resourcesDirectoryNode?.ForEach(scope (node) => {
			_pathToAssetNode.Remove(node->Path);
			_identifierToAssetNode.Remove(node->Identifier);
		});
		_assetRootNode.RemoveChild(_resourcesDirectoryNode);
		DeleteTreeAndChildren!(_resourcesDirectoryNode);
		_resourcesDirectoryNode = null;

		if (!Directory.Exists(ResourcesDirectory))
		{
			Log.EngineLogger.Error($"Resources directory \"{ResourcesDirectory}\" doesn't exist.");
			return;
		}
		
		AssetNode assetNode = new AssetNode();
		assetNode.Path = new String(ResourcesDirectory);
		assetNode.Name = new String();
		assetNode.Identifier = new String("###resources");
		assetNode.IsDirectory = true;
		Path.GetFileName(assetNode.Path, assetNode.Name);

		_resourcesDirectoryNode = _assetRootNode.AddChild(assetNode);
		_pathToAssetNode.Add(assetNode.Path, _resourcesDirectoryNode);
		_identifierToAssetNode.Add(assetNode.Identifier, _resourcesDirectoryNode);

		Log.EngineLogger.Trace($"Created directory node for: \"{ResourcesDirectory}\"");

		_fileSystemDirty = true;

		// TODO: Watch resources folder?
		//SetupResourcesFileSystemWatcher();

		Update();
	}

	/// Sets path to the directory that contains the game assets.
	public void SetAssetsDirectory(StringView fileName)
	{
		AssetsDirectory = fileName;
		
		_assetsDirectoryNode?.ForEach(scope (node) => {
			_pathToAssetNode.Remove(node->Path);
			_identifierToAssetNode.Remove(node->Identifier);
		});
		_assetRootNode.RemoveChild(_assetsDirectoryNode);
		DeleteTreeAndChildren!(_assetsDirectoryNode);
		_assetsDirectoryNode = null;
		
		if (!Directory.Exists(AssetsDirectory))
		{
			// TODO: This is not an error, if no project is loaded
			Log.EngineLogger.Warning($"Assets directory \"{AssetsDirectory}\" doesn't exist.");
			return;
		}
		
		AssetNode assetNode = new AssetNode();
		assetNode.Path = new String(AssetsDirectory);
		assetNode.Name = new String();
		assetNode.Identifier = new String("###assets");
		assetNode.IsDirectory = true;
		Path.GetFileName(assetNode.Path, assetNode.Name);

		_assetsDirectoryNode = _assetRootNode.AddChild(assetNode);
		_pathToAssetNode.Add(assetNode.Path, _assetsDirectoryNode);
		_identifierToAssetNode.Add(assetNode.Identifier, _assetsDirectoryNode);

		Log.EngineLogger.Trace($"Created directory node for: \"{AssetsDirectory}\"");

		_fileSystemDirty = true;

		SetupFileSystemWatcher();

		Update();
	}
	
	/// Initializes the FSW for the current ContentDirectory and registers the events.
	private void SetupFileSystemWatcher()
	{
		delete fsw;
		fsw = new FileSystemWatcher(_assetsDirectory);
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
			
			FileRenamed(oldName, newName);
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

	/// Gets the tree node for the given asset identifier or .Err, if the file/directory doesn't exist.
	/// @param filePath the path for which to return the tree node.
	/// @remarks Do not hold a reference to the TreeNode because it can become invalid when the file hierarchy changes.
	public Result<TreeNode<AssetNode>> GetNodeFromIdentifier(StringView identifier)
	{
		if (_identifierToAssetNode.TryGetValue(identifier, let treeNode))
		{
			return treeNode;
		}

		return .Err;
	}

	/// Gets the tree node for the given asset handle; or .Err, if no file exists with the given handle.
	/// @param filePath the path for which to return the tree node.
	/// @remarks Do not hold a reference to the TreeNode because it can become invalid when the file hierarchy changes.
	public Result<TreeNode<AssetNode>> GetNodeFromAssetHandle(AssetHandle assetHandle)
	{
		if (_handleToAssetNode.TryGetValue(assetHandle, let treeNode))
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
	
	/// Determines and set the Identfier for the given asset node.
	private void DetermineIdentifier(TreeNode<AssetNode> assetNode)
	{
		if (assetNode->Identifier == null)
			assetNode->Identifier = new String();

		assetNode->Identifier.Clear();

		// Get the Identifier which is simply the path relative to the asste root (either Resources- or Assets-Folder)
		if (assetNode.IsInSubtree(_resourcesDirectoryNode))
		{
			Path.GetRelativePath(assetNode->Path, _resourcesDirectoryNode->Path, assetNode->Identifier);
			assetNode->Identifier.Insert(0, "Resources/");
		}
		else if (assetNode.IsInSubtree(_assetsDirectoryNode))
		{
			Path.GetRelativePath(assetNode->Path, _assetsDirectoryNode->Path, assetNode->Identifier);
			assetNode->Identifier.Insert(0, "Assets/");
		}
		AssetIdentifier.Fixup(assetNode->Identifier);
	}

	/// Rebuilds the asset file hierarchy.
	private void UpdateFiles()
	{
		Log.EngineLogger.Trace($"Updating asset hierarchy");

		void HandleFile(AssetNode node)
		{
			node.AssetFile = new AssetFile(_contentManager, node.Identifier, node.Path, node.IsDirectory);
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
				filepathBuffer.Replace(Path.AltDirectorySeparatorChar, Path.DirectorySeparatorChar);

				// Ignore meta files.
				if (extensionBuffer.Equals(AssetFile.ConfigFileExtension, .OrdinalIgnoreCase))
					continue;

				TreeNode<AssetNode> treeNode = directory.Children.Where(scope (node) => node.Value.Path == filepathBuffer).FirstOrDefault();

				if (treeNode == null)
				{
					AssetNode assetNode = new AssetNode();
					assetNode.Name = new String();
					Path.GetFileName(filepathBuffer, assetNode.Name);
					
					assetNode.Path = new String(filepathBuffer);
					assetNode.IsDirectory = false;
					
					treeNode = directory.AddChild(assetNode);
					
					DetermineIdentifier(treeNode);

					_pathToAssetNode.Add(assetNode.Path, treeNode);
					_identifierToAssetNode.Add(assetNode.Identifier, treeNode);

					//GrabSubAssets(node);
					HandleFile(treeNode.Value);

					_handleToAssetNode.Add(assetNode.AssetFile.AssetConfig.AssetHandle, treeNode);

					Log.EngineLogger.Trace($"Created file node for: \"{assetNode.Path}\"");
				}
			}
		}

		void RemoveOrphanedEntries(TreeNode<AssetNode> node)
		{
			for (TreeNode<AssetNode> child in node.Children)
			{
				if (!Directory.Exists(child->Path) && !File.Exists(child->Path))
				{
					Log.EngineLogger.Trace($"Removed orphaned node for: \"{child->Path}\"");

					@child.Remove();

					child.ForEach(scope (node) => {
						_pathToAssetNode.Remove(node->Path);
						_identifierToAssetNode.Remove(node->Identifier);
					});

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
				//assetNode.Identifier = new String();
				assetNode.IsDirectory = true;
				Path.GetFileName(assetNode.Path, assetNode.Name);

				/*// Get the Identifier which is simply the path relative to the asste root (either Resources- or Assets-Folder)
				if (parentNode == _resourcesDirectoryNode || parentNode.IsChildOf(_resourcesDirectoryNode))
				{
					Path.GetRelativePath(assetNode.Path, _resourcesDirectoryNode->Path, assetNode.Identifier);
					assetNode.Identifier.Insert(0, "Resources/");
				}
				else
				{
					Path.GetRelativePath(assetNode.Path, _assetsDirectoryNode->Path, assetNode.Identifier);
					assetNode.Identifier.Insert(0, "Assets/");
				}
				AssetIdentifier.Fixup(assetNode.Identifier);*/

				treeNode = parentNode.AddChild(assetNode);
				
				DetermineIdentifier(treeNode);

				_pathToAssetNode.Add(assetNode.Path, treeNode);
				// No Identifiers for Directories, because we can't use directories as Assets anyways...
				//_identifierToAssetNode.Add(assetNode.Identifier, treeNode);

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
			
			RemoveOrphanedEntries(treeNode);
			AddFilesOfDirectory(treeNode);
		}

		if (!AssetsDirectory.IsWhiteSpace)
		{
			String filter = scope $"{AssetsDirectory}/*";

			String directoryNameBuffer = scope String(256);

			for (var directory in Directory.Enumerate(filter, .Directories))
			{
				directory.GetFilePath(directoryNameBuffer..Clear());

				AddDirectoryToTree(directoryNameBuffer, _assetsDirectoryNode);
			}

			RemoveOrphanedEntries(_assetsDirectoryNode);
			AddFilesOfDirectory(_assetsDirectoryNode);
		}
		
		if (!ResourcesDirectory.IsWhiteSpace)
		{
			String filter = scope $"{ResourcesDirectory}/*";

			String directoryNameBuffer = scope String(256);
	
			for (var directory in Directory.Enumerate(filter, .Directories))
			{
				directory.GetFilePath(directoryNameBuffer..Clear());
	
				AddDirectoryToTree(directoryNameBuffer, _resourcesDirectoryNode);
			}
			
			RemoveOrphanedEntries(_resourcesDirectoryNode);
			AddFilesOfDirectory(_resourcesDirectoryNode);
		}

		//*String filter = scope $"{AssetsDirectory}/*";
		/*
		String directoryNameBuffer = scope String(256);

		for (var directory in Directory.Enumerate(filter, .Directories))
		{
			directory.GetFilePath(directoryNameBuffer..Clear());

			AddDirectoryToTree(directoryNameBuffer, _assetHierarchy);
		}
		
		RemoveOrphanedEntries(_assetHierarchy);*/

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
		Path.InternalCombine(fileNameWithContentRoot, _assetsDirectory, fileName);

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
		Path.InternalCombine(oldFileNameWithContentRoot, _assetsDirectory, oldFilePath);
		
		String newFileNameWithContentRoot = scope .();
		Path.InternalCombine(newFileNameWithContentRoot, _assetsDirectory, newFilePath);
		
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
		_identifierToAssetNode.Remove(node->Identifier);

		node->Path.Set(newFileNameWithContentRoot);
		_pathToAssetNode.Add(node->Path, node);

		DetermineIdentifier(node);
		_identifierToAssetNode.Add(node->Identifier, node);
		
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
