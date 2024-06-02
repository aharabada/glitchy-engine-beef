using GlitchyEngine;
using GlitchyEngine.Collections;
using GlitchyEngine.Renderer;
using System;
using System.Collections;
using System.IO;
using System.Linq;
using GlitchyEngine.Content;

namespace GlitchyEditor.Assets;

class AssetHierarchy
{
	FileSystemWatcher fsw ~ {
		_.StopRaisingEvents();
		delete _;
	};
	
	internal TreeNode<AssetNode> _assetRootNode = null ~ DeleteTreeAndChildren!(_);
	internal TreeNode<AssetNode> _resourcesDirectoryNode = null;
	internal TreeNode<AssetNode> _assetsDirectoryNode = null;
	private append Dictionary<StringView, TreeNode<AssetNode>> _pathToAssetNode = .();
	private append Dictionary<StringView, TreeNode<AssetNode>> _identifierToAssetNode = .();
	private append Dictionary<AssetHandle, TreeNode<AssetNode>> _handleToAssetNode = .();
	
	private append String _resourcesDirectory = .();
	private append String _assetsDirectory = .();

	private const float FileSystemDebounceSeconds = 0.5f;

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

		StringView assetDescriptorPath = assetNode.AssetFile?.AssetConfigPath ?? "";

		// If it exists, also try to delete the .ass file
		if (File.Exists(assetDescriptorPath))
		{
			if (File.Delete(assetDescriptorPath) case .Err(let error))
			{
				Log.EngineLogger.Error($"Couldn't delete Asset descriptor file \"{assetDescriptorPath}\" ({error}).");
			}
		}
	}

	/// Renames the given assetNode to the specified name.
	public void RenameFile(AssetNode assetNode, StringView fileName)
	{
		String directory = scope .();
		if (Path.GetDirectoryPath(assetNode.Path, directory) case .Err)
		{
			Log.EngineLogger.Error($"Rename failed. Couldn't get directory for path \"{assetNode.Path}\".");
			return;
		}

		String newName = scope .();
		Path.Combine(newName, directory, fileName);

		if (File.Move(assetNode.Path, newName) case .Err(let error))
		{
			Log.EngineLogger.Error($"Couldn't rename file from {assetNode.Path} to {newName} ({error}).");
		}

		// We don't need to rename the .ass file, because the filesystem watcher will handle this for us!
	}

	public Result<void> MoveFileToNode(StringView assetIdentifierToMove, TreeNode<AssetNode> newParentEntry)
	{
		TreeNode<AssetNode> fileToMove = GetNodeFromIdentifier(assetIdentifierToMove).GetValueOrDefault();

		if (fileToMove == null)
		{
			Log.EngineLogger.Error($"Couldn't find asset node for asset {assetIdentifierToMove}");
			return .Err;
		}

		String newPathName = scope .();
		Path.Combine(newPathName, newParentEntry->Path, fileToMove->Name);

		if (File.Exists(newPathName))
		{
			Log.EngineLogger.Error("Can't move file. Target already exists.");
			return .Err;
		}

		if (fileToMove->IsDirectory)
		{
			if (Directory.Move(fileToMove->Path, newPathName) case .Err(let error))
			{
				Log.EngineLogger.Error($"Couldn't move directory from {fileToMove->Path} to {newPathName} ({error}).");
				return .Err;
			}
		}
		else
		{
			if (File.Move(fileToMove->Path, newPathName) case .Err(let error))
			{
				Log.EngineLogger.Error($"Couldn't move file from {fileToMove->Path} to {newPathName} ({error}).");
				return .Err;
			}
		}

		if (fileToMove->AssetFile != null)
		{
			if (File.Exists(fileToMove->AssetFile.AssetConfigPath))
			{
				String newConfigPathName = scope .(newPathName);
				newConfigPathName.Append(AssetFile.ConfigFileExtension);

				if (File.Move(fileToMove->AssetFile.AssetConfigPath, newConfigPathName) case .Err(let error))
				{
					Log.EngineLogger.Error($"Couldn't move asset description file from {fileToMove->AssetFile.AssetConfigPath} to {newConfigPathName} ({error}). Sorry :(");
					return .Err;
				}
			}
		}

		return .Ok;
	}
	
	/// Sets path to the directory that contains the engine assets.
	public void SetResourcesDirectory(StringView fileName)
	{
		ResourcesDirectory = fileName;

		_resourcesDirectoryNode?.ForEach(scope (node) => {
			_pathToAssetNode.Remove(node->Path);
			_identifierToAssetNode.Remove(node->Identifier);

			let handle = node->AssetFile?.AssetConfig?.AssetHandle;
			if (handle != null)
				_handleToAssetNode.Remove(handle.Value);
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
		assetNode.Identifier = new AssetIdentifier("###resources");
		assetNode.IsDirectory = true;
		Path.GetFileName(assetNode.Path, assetNode.Name);

		_resourcesDirectoryNode = _assetRootNode.AddChild(assetNode);
		_pathToAssetNode.Add(assetNode.Path, _resourcesDirectoryNode);
		_identifierToAssetNode.Add(assetNode.Identifier, _resourcesDirectoryNode);

		Log.EngineLogger.Trace($"Created directory node for: \"{ResourcesDirectory}\"");

		// TODO: Watch resources folder?
		//SetupResourcesFileSystemWatcher();

		UpdateFiles();
	}

	/// Sets path to the directory that contains the game assets.
	public void SetAssetsDirectory(StringView fileName)
	{
		if (AssetsDirectory == fileName)
			return;

		AssetsDirectory = fileName;
		
		_assetsDirectoryNode?.ForEach(scope (node) => {
			_pathToAssetNode.Remove(node->Path);
			_identifierToAssetNode.Remove(node->Identifier);

			let handle = node->AssetFile?.AssetConfig?.AssetHandle;
			if (handle != null)
				_handleToAssetNode.Remove(handle.Value);
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
		assetNode.Identifier = new AssetIdentifier("###assets");
		assetNode.IsDirectory = true;
		Path.GetFileName(assetNode.Path, assetNode.Name);

		_assetsDirectoryNode = _assetRootNode.AddChild(assetNode);
		_pathToAssetNode.Add(assetNode.Path, _assetsDirectoryNode);
		_identifierToAssetNode.Add(assetNode.Identifier, _assetsDirectoryNode);

		Log.EngineLogger.Trace($"Created directory node for: \"{AssetsDirectory}\"");

		SetupFileSystemWatcher();

		UpdateFiles();
	}

	private bool _fileTreeUpdateRequested = false;

	private float _fileSystemDebounce;

	/// Invokes the the file tree update on the mainthread.
	private void DeferFileTreeUpdate()
	{
		_fileSystemDebounce = FileSystemDebounceSeconds;

		if (!_fileTreeUpdateRequested)
		{
			_fileTreeUpdateRequested = true;

			Application.Instance.InvokeOnMainThread(new () =>
				{
					_fileSystemDebounce -= Application.Instance.GameTime.DeltaTime;
					
					if (_fileSystemDebounce > 0)
						return false;

					UpdateFiles();
					_fileTreeUpdateRequested = false;

					return true;
				});
		}
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

			FileContentChanged(filename);
		});

		fsw.OnCreated.Add(new (filename) => {
			Log.EngineLogger.Trace($"File created (\"{filename}\")");

			DeferFileTreeUpdate();
		});

		fsw.OnDeleted.Add(new (filename) => {
			Log.EngineLogger.Trace($"File deleted (\"{filename}\")");

			DeferFileTreeUpdate();
		});

		fsw.OnRenamed.Add(new (oldName, newName) => {
			Log.EngineLogger.Trace($"File renamed (From \"{oldName}\" to \"{newName}\")");
			
			FileRenamed(oldName, newName);
			
			DeferFileTreeUpdate();
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

	/// Determines and set the Identifier for the given asset node.
	private void DetermineIdentifier(TreeNode<AssetNode> assetNode)
	{
		String identifier = scope .();

		// Get the Identifier which is simply the path relative to the asste root (either Resources- or Assets-Folder)
		if (assetNode.IsInSubtree(_resourcesDirectoryNode))
		{
			Path.GetRelativePath(assetNode->Path, _resourcesDirectoryNode->Path, identifier);
			identifier.Insert(0, AssetIdentifier.ResourcesPrefix);
		}
		else if (assetNode.IsInSubtree(_assetsDirectoryNode))
		{
			Path.GetRelativePath(assetNode->Path, _assetsDirectoryNode->Path, identifier);
			identifier.Insert(0, AssetIdentifier.AssetsPrefix);
		}

		delete assetNode->Identifier;
		assetNode->Identifier = new AssetIdentifier(identifier);
	}

	/// Scans the tree for orphaned nodes and removes them.
	void RemoveOrphanedEntries(TreeNode<AssetNode> node)
	{
		for (TreeNode<AssetNode> child in node.Children)
		{
			if (!Directory.Exists(child->Path) && !File.Exists(child->Path))
			{
				Log.EngineLogger.Trace($"Removing orphaned node for: \"{child->Path}\"");

				@child.Remove();

				// Remove entire subtree from all maps
				child.ForEach(scope (node) => {
					_pathToAssetNode.Remove(node->Path);
					_identifierToAssetNode.Remove(node->Identifier);

					if (node->AssetFile != null)
					{
						_handleToAssetNode.Remove(node->AssetFile.AssetConfig.AssetHandle);
					}

					Log.EngineLogger.Trace($"Removed orphaned node from tree {node->Path} ({node->AssetFile?.AssetConfig.AssetHandle})");
				});

				DeleteTreeAndChildren!(child);
			}
			else
			{
				RemoveOrphanedEntries(child);
			}
		}
	}

	/// Rebuilds the asset file hierarchy.
	private void UpdateFiles()
	{
		Log.EngineLogger.Trace($"Updating asset hierarchy");

		// Cleanup entire tree first to avoid 
		RemoveOrphanedEntries(_assetRootNode);

		/// Creates a TreeNode for the given file path.
		/// @param fileName The name of the file/directory to add to the tree.
		/// @param isDirectory If True, the Entry will be added as a directory
		/// @param parentNode The node that is the parentNode in the tree
		TreeNode<AssetNode> CreateTreeNode(String filePath, bool isDirectory, TreeNode<AssetNode> parentNode)
		{
			AssetNode assetNode = new AssetNode();
			assetNode.Path = new String(filePath);
			assetNode.Name = new String();
			assetNode.IsDirectory = isDirectory;

			Path.GetFileName(filePath, assetNode.Name);

			TreeNode<AssetNode> treeNode = parentNode.AddChild(assetNode);

			DetermineIdentifier(treeNode);

			_pathToAssetNode.Add(assetNode.Path, treeNode);
			_identifierToAssetNode.Add(assetNode.Identifier, treeNode);

			// Only files get AssetFile and AssetHandle
			if (!isDirectory)
			{
				// TODO: Subassets -> Happens in processor!
				//GrabSubAssets(node);

				// TODO: Apparently directories were supposed to get an AssetFile? Makes sense, we wanted to have settings for directories, too!
				treeNode->AssetFile = AssetFile.LoadOrCreateAssetFile(_contentManager, assetNode);

				_handleToAssetNode.Add(assetNode.AssetFile.AssetConfig.AssetHandle, treeNode);
			}

			Log.EngineLogger.Trace($"Created {(isDirectory ? "directory" : "file")} node for: \"{assetNode.Path}\"");

			return treeNode;
		}

		/// If necessary adds a tree node for the given file path. For Directories also adds files and subdirectories.
		/// @param fileName The name of the file/directory to add to the tree.
		/// @param isDirectory If True, the Entry will be added as a directory
		/// @param parentNode The node that is the parentNode in the tree
		void AddEntryToTree(String filePath, bool isDirectory, TreeNode<AssetNode> parentNode)
		{
			// Try to find the node for the specified path in the given parent
			TreeNode<AssetNode> treeNode = parentNode.Children.Where(scope (node) => node.Value.Path == filePath).FirstOrDefault();

			// If no node was found -> create one
			if (treeNode == null)
				treeNode = CreateTreeNode(filePath, isDirectory, parentNode);

			if (isDirectory)
				AddSubdirectoriesAndFilesToTree(treeNode);
		}

		/// Adds the subdirectories of the given directory to the tree
		/// @param directoryNode The node of the directory whose subdirectories and files will be added.
		void AddSubdirectoriesAndFilesToTree(TreeNode<AssetNode> directoryNode)
		{
			// Filter that finds all entries of a directory.
			String filter = scope $"{directoryNode->Path}/*";

			String filePathBuffer = scope String(256);
			String fileExtensionBuffer = scope String(16);

			for (var entry in Directory.Enumerate(filter, .Directories | .Files))
			{
				entry.GetFilePath(filePathBuffer..Clear());
				filePathBuffer.Replace(Path.AltDirectorySeparatorChar, Path.DirectorySeparatorChar);

				if (!entry.IsDirectory)
				{
					// For files we have to check whether or not the file ends with .ass

					fileExtensionBuffer.Clear();
					Path.GetExtension(filePathBuffer, fileExtensionBuffer);
					
					// Ignore meta files.
					if (fileExtensionBuffer.Equals(AssetFile.ConfigFileExtension, .OrdinalIgnoreCase))
						continue;
				}
				
				AddEntryToTree(filePathBuffer, entry.IsDirectory, directoryNode);
			}
		}

		if (!AssetsDirectory.IsWhiteSpace)
			AddSubdirectoriesAndFilesToTree(_assetsDirectoryNode);
		
		if (!ResourcesDirectory.IsWhiteSpace)
			AddSubdirectoriesAndFilesToTree(_resourcesDirectoryNode);
	}

	private void FileContentChanged(StringView fileName)
	{
		var fileName;

		// Config files aren't really tracked but changing them effectively changes the corresponding file
		// so we fire the event for them.
		if (fileName.EndsWith(AssetFile.ConfigFileExtension))
			fileName.RemoveFromEnd(AssetFile.ConfigFileExtension.Length);

		String fileNameWithContentRoot = scope .();
		Path.Combine(fileNameWithContentRoot, _assetsDirectory, fileName);

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

		if (!(node->AssetFile?.UseNewAssetPipeline ?? false))
			OnFileContentChanged(node.Value);

		_fileSystemDebounce = FileSystemDebounceSeconds;

		Application.Instance.InvokeOnMainThread(new () => {
			_fileSystemDebounce -= Application.Instance.GameTime.DeltaTime;
			if (_fileSystemDebounce > 0)
				return false;

			node->AssetFile?.CheckForReprocessing();

			return true;
		});

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
				// TODO: Actually Move, but it's a bit complicated to manage cases, where external programs move the original file and
				// rename an new file to the original name. So just copy the config to retain it.
				// I don't think there is a clean way to solve this.
				if (File.Copy(oldConfigFileName, newConfigFileName) case .Err(let value))
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

		// Save the old identifier
		String oldIdentifier = scope .(node->Identifier);

		_pathToAssetNode.Remove(oldFileNameWithContentRoot);
		_identifierToAssetNode.Remove(node->Identifier);

		node->Path.Set(newFileNameWithContentRoot);
		_pathToAssetNode.Add(node->Path, node);
		
		// Updates node->Identifier
		DetermineIdentifier(node);

		_identifierToAssetNode.Add(node->Identifier, node);
		
		node->Name.Clear();
		Path.GetFileName(newFileNameWithContentRoot, node->Name);

		// Directories have no AssetFile?
		if (node->AssetFile != null)
		{
			node->Path.Set(newFilePath);

			delete node->Identifier;
			node->Identifier = new AssetIdentifier(newFilePath);

			node->AssetFile.[Friend]_assetConfigPath.Set(node->Path);
			node->AssetFile.[Friend]_assetConfigPath.Append(AssetFile.ConfigFileExtension);
		}

		// Fire renamed event (e.g. because EditorContentManager needs to know)
		OnFileRenamed(node.Value, oldIdentifier);
	}

	public delegate void FileContentChangedFunc(AssetNode node);

	public Event<FileContentChangedFunc> OnFileContentChanged ~ _.Dispose();

	public delegate void FileRenamedFunc(AssetNode node, StringView oldName);

	public Event<FileRenamedFunc> OnFileRenamed ~ _.Dispose();
}
