using System;
using System.IO;
using GlitchyEngine.Collections;
using System.Collections;
using GlitchyEngine.Renderer;
using System.Threading;
using GlitchyEngine.Content;
using GlitchyEditor.Assets;
using GlitchyEngine;
using System.Linq;

namespace GlitchyEditor;

/*class PreviewImageManager
{
	/// Thread that loads/generates preview images in the background
	//private Thread _loaderThread;

	/// Set to true to notify the loader to stop
	//private bool _stopLoader;

	private append Dictionary<String, Texture2D> _previewImages = .() ~ {
		for (var v in _)
		{
			delete v.key;
			v.value.ReleaseRef();
		}

		delete _;
	};

	public Texture2D GetPreviewImage(String assetName)
	{
		if (_previewImages.TryGetValue(assetName, let image))
		{
			return image..AddRef();
		}

		if (assetName.EndsWith(".png", .OrdinalIgnoreCase))
		{
			/*using (Texture2D texture = new Texture2D(assetName, true))
			{
				Texture2DDesc desc = .(128, 128, .R8G8B8A8_UNorm_SRGB)
					{
						Usage = .Immutable
					};

				Texture2D myActualTexture = new Texture2D(desc);

				// TODO: Scale down texture (on GPU?)
			}*/

			Texture2D texture = new Texture2D(assetName, true);

			if (texture.Width <= 128 && texture.Height <= 128)
			{

			}

			if ( texture.MipLevels > 1)
			{

			}

			_previewImages.Add(new String(assetName), texture);

			return texture..AddRef();
		}
		else
		{
			Runtime.NotImplemented();
		}
	}
}*/

public class AssetNode
{
	public String Name ~ delete _;
	public String Path ~ delete _;

	public bool IsDirectory;

	public AssetFile AssetFile ~ delete _;

	public List<Asset> SubAssets ~ {
		SubAssets?.ClearAndDeleteItems();
		delete SubAssets;
	}

	public Texture2D PreviewImage ~ _?.ReleaseRef();
}

public class Asset
{
	public AssetNode Asset;
	public String Name ~ delete _;
	//public String AssetInternalPath ~ delete _;

	public Texture2D PreviewImage ~ _?.ReleaseRef();
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
			
			_fileSystemDirty = true;
			/*String contentFilePath = scope String();

			Path.InternalCombine(contentFilePath, ContentDirectory, oldName);

			//_fileSystemDirty = true;
			TreeNode<AssetNode> fileNode = GetNodeFromPath(contentFilePath);
			fileNode->*/
		});

		fsw.StartRaisingEvents();
	}

	/// Gets the tree node for the given filePath or null, if the file/directory doesn't exist.
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

			Log.EngineLogger.Trace($"Created directory node for: \"{_assetHierarchy->Path}\"");

			_pathToAssetNode.Add(ContentDirectory, _assetHierarchy);
		}

		void HandleFile(AssetNode node)
		{
			node.AssetFile = new AssetFile(_contentManager, node.Path, node.IsDirectory);
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
			Log.EngineLogger.Error($"Could not find node for file \"{fileNameWithContentRoot}\"");
		}

		// Don't fire event for directories.
		if (node->IsDirectory)
			return;

		OnFileContentChanged(node.Value);

		// TODO: Handle file changes (reload asset, etc...)
	}

	public delegate void FileContentChangedFunc(AssetNode node);

	public Event<FileContentChangedFunc> OnFileContentChanged ~ _.Dispose();
}

class EditorContentManager : IContentManager
{
	// TODO: Get from workspace
	//const String ContentDirectory  = "./content";

	private append String _contentDirectory = .();

	public StringView ContentDirectory => _contentDirectory;
	
	private append List<String> _identifiers = .() ~ _.ClearAndDeleteItems();

	private append Dictionary<StringView, IRefCounted> _loadedAssets = .(); // Check if all resources are unloaded
	
	private append AssetHierarchy _assetHierarchy = .(this);

	public AssetHierarchy AssetHierarchy => _assetHierarchy;

	public this()
	{
		_assetHierarchy.OnFileContentChanged.Add(new => OnFileContentChanged);
	}

	private void OnFileContentChanged(AssetNode assetNode)
	{
		// Asset isn't loaded so we don't need to reload it.
		if (assetNode.AssetFile.LoadedAsset == null)
			return;

		String neededAssetLoaderName = assetNode.AssetFile.AssetConfig?.AssetLoader;

		if (String.IsNullOrWhiteSpace(neededAssetLoaderName))
			return;

		IAssetLoader assetLoader = null;

		String loaderNameBuffer = scope String(64);

		for (IAssetLoader loader in _assetLoaders)
		{
			loader.GetType().GetName(loaderNameBuffer..Clear());

			if (loaderNameBuffer == neededAssetLoaderName)
			{
				assetLoader = loader;
				break;
			}
		}

		if (assetLoader == null)
		{
			Log.EngineLogger.Error($"Could not find asset loader \"{neededAssetLoaderName}\"");
			return;
		}

		if (var assetReloader = assetLoader as IReloadingAssetLoader)
		{
			Stream stream = GetStream(assetNode.Path);

			assetReloader.ReloadAsset(assetNode.AssetFile, stream);

			delete stream;
		}
	}

	public void SetContentDirectory(StringView contentDirectory)
	{
		_contentDirectory.Clear();
		_contentDirectory.Append(contentDirectory);
		Path.Fixup(_contentDirectory);

		_assetHierarchy.SetContentDirectory(contentDirectory);
	}

	public void Update()
	{
		_assetHierarchy.Update();
	}

	public IAssetLoader GetDefaultAssetLoader(StringView fileExtension)
	{
		if (_defaultAssetLoaders.TryGetValue(fileExtension, let value))
			return value;

		return null;
	}
	private append List<String> _supportedExtensions = .() ~ ClearAndDeleteItems!(_);
	private append List<IAssetLoader> _assetLoaders = .() ~ ClearAndDeleteItems!(_);
	private append Dictionary<StringView, IAssetLoader> _defaultAssetLoaders = .();
	private append Dictionary<String, function AssetPropertiesEditor(AssetFile)> _assetPropertiesEditors = .() ~ {
		for (String key in _.Keys)
		{
			delete key;
		}
	};

	public void RegisterAssetLoader<T>() where T : new, class, IAssetLoader
	{
		//Log.EngineLogger.AssertDebug(!_assetLoaders.Any((l) => l.GetType() == typeof(T)), "Asset loader already registered.");

		_assetLoaders.Add(new T());

		for (StringView ext in T.FileExtensions)
			_supportedExtensions.Add(new String(ext));
	}

	public void SetAsDefaultAssetLoader<T>(params StringView[] fileExtensions) where T : IAssetLoader
	{
		for (var ext in fileExtensions)
		{
			// Find file extension in registered file extensions
			String foundExtension = null;

			for (var supportedExt in _supportedExtensions)
			{
				if (supportedExt == ext)
				{
					foundExtension = supportedExt;
					break;
				}
			}

			Log.EngineLogger.Assert(foundExtension != null, "File Extension is not registered.");
			
			for (var loader in _assetLoaders)
			{
				if (loader.GetType() == typeof(T))
				{
					_defaultAssetLoaders[foundExtension] = loader;
					break;
				}
			}
		}
	}
	
	public void SetAssetPropertiesEditor(Type assetLoaderType, function AssetPropertiesEditor(AssetFile) editorFactory)
	{
		String loaderTypeName = new String();
		assetLoaderType.GetName(loaderTypeName);

		_assetPropertiesEditors[loaderTypeName] = editorFactory;
	}

	public void SetAssetPropertiesEditor<TAssetLoader>(function AssetPropertiesEditor(AssetFile) editorFactory) where TAssetLoader : IAssetLoader
	{
		SetAssetPropertiesEditor(typeof(TAssetLoader), editorFactory);
	}

	public AssetPropertiesEditor GetNewPropertiesEditor(AssetFile assetFile)
	{
		if (assetFile?.AssetConfig.AssetLoader == null)
			return null;

		if (_assetPropertiesEditors.TryGetValue(assetFile.AssetConfig.AssetLoader, let propertiesEditorfactory))
			return propertiesEditorfactory(assetFile);

		return null;
	}

	public bool IsLoaded(StringView identifier)
	{
		return _loadedAssets.ContainsKey(identifier);
	}

	public IRefCounted LoadAsset(StringView identifier)
	{
		if (_loadedAssets.TryGetValue(identifier, let asset))
		{
			return asset..AddRef();
		}

		String filePath = scope String(identifier.Length + _contentDirectory.Length + 2);
		Path.Combine(filePath, _contentDirectory, identifier);

		Path.Fixup(filePath);

		//filePath.Replace(Path.AltDirectorySeparatorChar, Path.DirectorySeparatorChar);

		Result<TreeNode<AssetNode>> resultNode = AssetHierarchy.GetNodeFromPath(filePath);

		if (resultNode case .Err)
			Runtime.FatalError();

		//AssetFile file = scope .(this, filePath, false);
		AssetFile file = resultNode->Value.AssetFile;
		
		IAssetLoader assetLoader = null;

		String loaderTypeName = scope .(128);

		for (IAssetLoader loader in _assetLoaders)
		{
			loader.GetType().GetName(loaderTypeName..Clear());

			if (loaderTypeName == file.AssetConfig.AssetLoader)
			{
				assetLoader = loader;
				break;
			}
		}

		Log.EngineLogger.AssertDebug(assetLoader != null);

		Stream stream = GetStream(filePath);

		IRefCounted loadedAsset = assetLoader.LoadAsset(stream, file.AssetConfig.Config);

		String identifierString = new .(identifier);
		_identifiers.Add(identifierString);
		_loadedAssets[identifierString] = loadedAsset;

		delete stream;

		file.[Friend]_loadedAsset = loadedAsset;

		return loadedAsset;
	}

	// TODO: probably not needed
	public Stream GetStream(StringView assetIdentifier)
	{
		FileStream fs = new FileStream();
		var result = fs.Open(assetIdentifier, .Open, .Read, .ReadWrite);

		return fs;
	}
}