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

class EditorContentManager : IContentManager
{
	// TODO: Get from workspace
	//const String ContentDirectory  = "./content";
	
	FileSystemWatcher fsw ~ {
		_.StopRaisingEvents();
		delete _;
	};
	
	bool _fileSystemDirty = false;

	internal TreeNode<AssetNode> _assetHierarchy = null /*new TreeNode<AssetNode>()*/ ~ DeleteTreeAndChildren!(_);

	private append String _contentDirectory = .();

	public StringView ContentDirectory => _contentDirectory;
	
	private append List<String> _identifiers = .() ~ _.ClearAndDeleteItems();

	private append Dictionary<StringView, IRefCounted> _loadedAssets = .(); // Check if all resources are unloaded

	public this()
	{
	}

	public void SetContentDirectory(StringView contentDirectory)
	{
		_contentDirectory.Clear();
		_contentDirectory.Append(contentDirectory);
		_fileSystemDirty = true;

		SetupFileSystemWatcher();
	}

	/// Initializes the FSW for the current ContentDirectory and registers the events.
	private void SetupFileSystemWatcher()
	{
		delete fsw;
		fsw = new FileSystemWatcher(ContentDirectory);
		fsw.IncludeSubdirectories = true;

		fsw.OnChanged.Add(new (filename) => {
			_fileSystemDirty = true;
		});

		fsw.OnCreated.Add(new (filename) => {
			_fileSystemDirty = true;
		});

		fsw.OnDeleted.Add(new (filename) => {
			_fileSystemDirty = true;
		});

		fsw.OnRenamed.Add(new (newName, oldName) => {
			_fileSystemDirty = true;
		});

		fsw.StartRaisingEvents();
	}

	public void Update()
	{
		// TODO: do we really need to do this in the update loop?
		if (_fileSystemDirty)
		{
			UpdateFiles();
		}
	}

	public IAssetLoader GetDefaultAssetLoader(StringView fileExtension)
	{
		if (_defaultAssetLoaders.TryGetValue(fileExtension, let value))
			return value;

		return null;
	}

	/// Rebuilds the asset file hierarchy.
	private void UpdateFiles()
	{
		// TODO: we don't need to rebuild the entire tree!
		//DeleteTreeAndChildren!(_assetHierarchy);

		if (_assetHierarchy == null)
		{
			// TODO: move to init?

			_assetHierarchy = new TreeNode<AssetNode>(new AssetNode());
			_assetHierarchy->Path = new String(ContentDirectory);
			_assetHierarchy->Name = new String("Content");
		}

		String str = scope .(ContentDirectory);
		
		/*void GrabSubAssets(TreeNode<AssetNode> assetNode)
		{
			// TODO: Dedicated asset loaders that register their extensions, etc....!

			if (assetNode->Name.EndsWith(".png", .OrdinalIgnoreCase))
			{
				assetNode->SubAssets = new:allocator List<Asset>();
				assetNode->SubAssets.Add(new:allocator Asset()
					{
						Asset = assetNode.Value,
						Name = new:allocator String(assetNode->Name)
					});
			}
			else if (assetNode->Name.EndsWith(".gltf", .OrdinalIgnoreCase) || assetNode->Name.EndsWith(".glb", .OrdinalIgnoreCase))
			{
				List<String> meshNames = scope List<String>();
				ModelLoader.GetMeshNames(assetNode->Path, meshNames);
				
				assetNode->SubAssets = new:allocator List<Asset>();

				for (var meshName in meshNames)
				{
					assetNode->SubAssets.Add(new:allocator Asset()
						{
							Asset = assetNode.Value,
							// Pass ownership of meshName to SubAsset -> save a copy and delete
							Name = meshName
						});
				}
			}
		}*/
		
		void HandleFile(AssetNode node)
		{
			node.AssetFile = new AssetFile(this, node.Path, node.IsDirectory);
		}

		void AddFilesOfDirectory(TreeNode<AssetNode> directory)
		{
			String filter = scope $"{directory->Path}/*";
			
			String buffer = scope String();
			String extensionBuffer = scope String();

			for (var entry in Directory.Enumerate(filter, .Files))
			{
				entry.GetFilePath(buffer..Clear());

				Path.GetExtension(buffer, extensionBuffer..Clear());

				// Don't add meta-files
				if (extensionBuffer == ".ass")
					continue;

				AssetNode e = new AssetNode();
				e.Name = new String();
				Path.GetFileName(buffer, e.Name);

				e.Path = new String(buffer);
				
				e.IsDirectory = entry.IsDirectory;

				var node = directory.AddChild(e);
				//GrabSubAssets(node);
				HandleFile(node.Value);
			}
		}

		void AddDirectoryToTree(String path, TreeNode<AssetNode> parentNode)
		{
			bool b (AssetNode node)
			{
				return false;
			}

			//void V() : 

			var v = parentNode.Children.First();

			AssetNode node = new AssetNode();
			node.Path = new String(path);
			node.Name = new String();
			node.IsDirectory = true;

			Path.GetFileName(node.Path, node.Name);

			var newNode = parentNode.AddChild(node);

			String filter = scope $"{path}/*";

			for (var directory in Directory.Enumerate(filter, .Directories))
			{
				directory.GetFilePath(str..Clear());

				AddDirectoryToTree(str, newNode);
			}

			AddFilesOfDirectory(newNode);
		}
		
		String filter = scope $"{ContentDirectory}/*";

		for (var directory in Directory.Enumerate(filter, .Directories))
		{
			directory.GetFilePath(str..Clear());

			AddDirectoryToTree(str, _assetHierarchy);
		}

		_fileSystemDirty = false;
	}

	private append List<String> _supportedExtensions = .() ~ ClearAndDeleteItems!(_);
	private append List<IAssetLoader> _assetLoaders = .() ~ ClearAndDeleteItems!(_);
	private append Dictionary<StringView, IAssetLoader> _defaultAssetLoaders = .();

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
		Path.InternalCombine(filePath, _contentDirectory, identifier);

		AssetFile file = scope .(this, filePath, false);
		
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