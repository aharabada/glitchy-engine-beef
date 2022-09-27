using System;
using System.IO;
using GlitchyEngine.Collections;
using System.Collections;
using GlitchyEngine.Renderer;
using System.Threading;
using GlitchyEngine.Content;

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

class EditorContentManager
{
	// TODO: Get from project
	const String ContentDirectory  = "./content";
	
	FileSystemWatcher fsw ~ {
		_.StopRaisingEvents();
		delete _;
	};

	bool _fileSystemDirty = true;
	
	public class AssetNode
	{
		public String Name ~ delete _;
		public String Path ~ delete _;

		public bool IsDirectory;

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

	internal TreeNode<AssetNode> _assetHierarchy = new TreeNode<AssetNode>() ~ DeleteTreeAndChildren!(_);

	public this()
	{
		SetupFileSystemWatcher();
	}

	/// Initializes the FSW for the current ContentDirectory and registers the events.
	private void SetupFileSystemWatcher()
	{
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
		if (_fileSystemDirty)
		{
			UpdateFiles();
		}
	}

	private void UpdateFiles()
	{
		DeleteTreeAndChildren!(_assetHierarchy);
		_assetHierarchy = new TreeNode<AssetNode>(new AssetNode());
		_assetHierarchy->Path = new String(ContentDirectory);
		_assetHierarchy->Name = new String("Content");
		
		String str = scope .(ContentDirectory);
		
		void GrabSubAssets(TreeNode<AssetNode> assetNode)
		{
			// TODO: Dedicated asset loaders that register their extensions, etc....!

			if (assetNode->Name.EndsWith(".png", .OrdinalIgnoreCase))
			{
				assetNode->SubAssets = new List<Asset>();
				assetNode->SubAssets.Add(new Asset()
					{
						Asset = assetNode.Value,
						Name = new String(assetNode->Name)
					});
			}
			else if (assetNode->Name.EndsWith(".gltf", .OrdinalIgnoreCase) || assetNode->Name.EndsWith(".glb", .OrdinalIgnoreCase))
			{
				List<String> meshNames = scope List<String>();
				ModelLoader.GetMeshNames(assetNode->Path, meshNames);
				
				assetNode->SubAssets = new List<Asset>();

				for (var meshName in meshNames)
				{
					assetNode->SubAssets.Add(new Asset()
						{
							Asset = assetNode.Value,
							// Pass ownership of meshName to SubAsset -> save a copy and delete
							Name = meshName
						});
				}
			}
		}

		void AddFilesOfDirectory(TreeNode<AssetNode> directory)
		{
			String filter = scope $"{directory->Path}/*";
			
			String buffer = scope String();

			for (var entry in Directory.Enumerate(filter, .Files))
			{
				entry.GetFilePath(buffer..Clear());

				AssetNode e = new AssetNode();
				e.Name = new String();
				Path.GetFileName(buffer, e.Name);

				e.Path = new String(buffer);
				
				e.IsDirectory = entry.IsDirectory;

				var node = directory.AddChild(e);
				GrabSubAssets(node);
			}
		}

		void AddDirectoryToTree(String path, TreeNode<AssetNode> parentNode)
		{
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
}