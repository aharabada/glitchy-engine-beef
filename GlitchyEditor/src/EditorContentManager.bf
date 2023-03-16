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

class EditorContentManager : IContentManager
{
	private append String _contentDirectory = .();

	public StringView ContentDirectory => _contentDirectory;
	
	//private append List<String> _identifiers = .() ~ _.ClearAndDeleteItems();

	private append Dictionary<StringView, AssetHandle> _identiferToHandle = .(); // TODO: Check if all resources are unloaded

	private append Dictionary<AssetHandle, Asset> _handleToAsset = .();

	private append AssetHierarchy _assetHierarchy = .(this);

	public AssetHierarchy AssetHierarchy => _assetHierarchy;

	private append List<AssetHandle> _reloadQueue = .();

	public this()
	{
		_assetHierarchy.OnFileContentChanged.Add(new => OnFileContentChanged);
	}

	public ~this()
	{
		UnmanageAllAssets();
	}

	private void OnFileContentChanged(AssetNode assetNode)
	{
		// TODO: update for AssetHandles

		// TODO: Subassets break reloading because we can't find them when we only receive the file that changed...

		// Asset isn't loaded so we don't need to reload it.
		if (assetNode.AssetFile.LoadedAsset == null)
			return;

		_reloadQueue.Add(assetNode.AssetFile.LoadedAsset.Handle);

		/*String neededAssetLoaderName = assetNode.AssetFile.AssetConfig?.AssetLoader;

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
		}*/

		/*if (var assetReloader = assetLoader as IReloadingAssetLoader)
		{
			Stream stream = GetStream(assetNode.Path);

			// TODO: reload asset

			//assetReloader.ReloadAsset(assetNode.AssetFile, stream);

			delete stream;
		}*/
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
		if (!_reloadQueue.IsEmpty)
		{
			for (AssetHandle handle in _reloadQueue)
			{
				ReloadAsset(handle);
			}
			_reloadQueue.Clear();
		}

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

	public void SetAsDefaultAssetLoader<T>(params Span<StringView> fileExtensions) where T : IAssetLoader
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
		return _identiferToHandle.ContainsKey(identifier);
	}
	
	public Asset GetAsset(Type assetType, AssetHandle handle)
	{
		Asset asset = null;

		_handleToAsset.TryGetValue(handle, out asset);

		if (assetType == null)
		{
			return asset;
		}
		else if (asset?.GetType().IsSubtypeOf(assetType) ?? false)
		{
			return asset;
		}
		else
		{
			// TODO: get default asset

			return null;
		}
	}

	private void ReloadAsset(AssetHandle handle)
	{
		Asset asset = null;

		if (!_handleToAsset.TryGetValue(handle, out asset))
		{
			Log.EngineLogger.Error("Can't reload! No asset exists for handle.");

			return;
		}

		Log.EngineLogger.AssertDebug(asset != null);

		StringView oldIdentifier = asset.Identifier;

		GetResourceAndSubassetName(oldIdentifier, let resourceName, let subassetName);
		
		String filePath = scope .();
		GetResourceFilePath(resourceName, filePath);

		//filePath.Replace(Path.AltDirectorySeparatorChar, Path.DirectorySeparatorChar);

		Result<TreeNode<AssetNode>> resultNode = AssetHierarchy.GetNodeFromPath(filePath);

		if (resultNode case .Err)
		{
			Log.EngineLogger.Error($"Could not find asset \"{filePath}\".");
			return;
		}

		AssetFile file = resultNode->Value.AssetFile;
		
		IAssetLoader assetLoader = GetAssetLoader(file);

		Stream stream = GetStream(filePath);

		Asset loadedAsset = assetLoader.LoadAsset(stream, file.AssetConfig.Config, resourceName, subassetName, this);

		delete stream;

		if (loadedAsset == null)
			return;

		loadedAsset.Identifier = oldIdentifier;
		loadedAsset.[Friend]_handle = handle;

		// Remove asset
		_identiferToHandle.Remove(oldIdentifier);
		Asset oldAsset = _handleToAsset[handle];
		oldAsset.ReleaseRef();

		_handleToAsset[handle] = loadedAsset;
		_identiferToHandle.Add(loadedAsset.Identifier, handle);

		file.[Friend]_loadedAsset = loadedAsset;
	}

	/// Returns the resource name and, if it exists, the subasset name.
	private void GetResourceAndSubassetName(StringView identifier, out StringView resourceName, out StringView? subassetName)
	{
		// Find subasset name
		int poundIndex = identifier.IndexOf('#');

		resourceName = poundIndex == -1 ? identifier : identifier.Substring(0, poundIndex);
		subassetName = identifier.Substring(poundIndex + 1);
	}

	private void GetResourceFilePath(StringView resourceName, String filePath)
	{
		Path.Combine(filePath, _contentDirectory, resourceName);

		Path.Fixup(filePath);
	}

	public AssetHandle LoadAsset(StringView identifier)
	{
		// Todo: How strict should we be on paths?
		String fixedIdentifier = scope String(identifier);
		// TODO: Fixup is more of a filesystem thingy... we might want to use our own function
		Path.Fixup(fixedIdentifier);

		if (_identiferToHandle.TryGetValue(fixedIdentifier, let asset))
		{
			return asset;
		}

		GetResourceAndSubassetName(fixedIdentifier, let resourceName, let subassetName);

		String filePath = scope .();
		GetResourceFilePath(resourceName, filePath);

		//filePath.Replace(Path.AltDirectorySeparatorChar, Path.DirectorySeparatorChar);

		Result<TreeNode<AssetNode>> resultNode = AssetHierarchy.GetNodeFromPath(filePath);

		if (resultNode case .Err)
		{
			Log.EngineLogger.Error($"Could not find asset \"{filePath}\".");
			return .Invalid;
		}

		AssetFile file = resultNode->Value.AssetFile;
		
		IAssetLoader assetLoader = GetAssetLoader(file);

		// TODO: what are we supposed to do if we don't find a loader? Sure not crash...
		Log.EngineLogger.AssertDebug(assetLoader != null);

		Stream stream = GetStream(filePath);

		Asset loadedAsset = assetLoader.LoadAsset(stream, file.AssetConfig.Config, resourceName, subassetName, this);
		
		delete stream;

		if (loadedAsset == null)
			return .Invalid;

		loadedAsset.Identifier = fixedIdentifier;
		AssetHandle handle = ManageAsset(loadedAsset);
		// ManageAsset increases RefCount, but this scope also holds a reference.
		loadedAsset.ReleaseRef();

		// Add to Identifier -> Handle map
		_identiferToHandle.Add(loadedAsset.Identifier, handle);

		file.[Friend]_loadedAsset = loadedAsset;

		return handle;
	}

	/// Gets the asset loader that has to be used for the given file.
	IAssetLoader GetAssetLoader(AssetFile file)
	{
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

		return assetLoader;
	}

	public enum SaveAssetError
	{
		case Unknown;
		case Unsavable;
		case PathNotFound;
	}

	/// Saves the asset.
	public Result<void, SaveAssetError> SaveAsset(Asset asset)
	{
		if (asset == null)
			return .Err(.Unknown);

		if (asset.Identifier.IsWhiteSpace)
			return .Err(.Unsavable);

		GetResourceAndSubassetName(asset.Identifier, let resourceName, let subassetName);

		if (subassetName != null)
		{
			// TODO: should this ever be allowed? Couldn't we just save the entire asset?
			// Would this ever be necessary?
			Runtime.NotImplemented("Saving subassets is not currently allowed");
		}

		String filePath = scope String();
		GetResourceFilePath(resourceName, filePath);

		Result<TreeNode<AssetNode>> assetNode = AssetHierarchy.GetNodeFromPath(filePath);

		if (assetNode case .Err)
			return .Err(.PathNotFound);

		AssetFile file = assetNode.Get()->AssetFile;

		IAssetLoader assetLoader = GetAssetLoader(file);

		IAssetSaver assetSaver = assetLoader as IAssetSaver;

		if (assetSaver == null)
		{
			Log.EngineLogger.Error("The asset loader can't save!");
			return .Err(.Unsavable);
		}

		Stream stream = OpenStream(filePath, false);

		assetSaver.EditorSaveAsset(stream, asset, file.AssetConfig.Config, resourceName, subassetName, this);

		// Trim off the end of the file.
		stream.SetLength(stream.Position);

		delete stream;

		return .Ok;
	}

	private Stream OpenStream(StringView assetIdentifier, bool openOnly)
	{
		var assetIdentifier;

		if (!assetIdentifier.StartsWith(_contentDirectory))
		{
			String filePath = scope:: String(assetIdentifier.Length + _contentDirectory.Length + 2);
			Path.Combine(filePath, _contentDirectory, assetIdentifier);

			assetIdentifier = filePath;
		}

		FileStream fs = new FileStream();

		FileMode fileMode = openOnly ? FileMode.Open : FileMode.OpenOrCreate;

		var result = fs.Open(assetIdentifier, fileMode, openOnly ? .Read : .ReadWrite, .ReadWrite);

		if (result case .Err)
			return null;

		return fs;
	}

	// TODO: probably not needed
	public Stream GetStream(StringView assetIdentifier)
	{
		return OpenStream(assetIdentifier, true);

		/*var assetIdentifier;

		if (!assetIdentifier.StartsWith(_contentDirectory))
		{
			String filePath = scope:: String(assetIdentifier.Length + _contentDirectory.Length + 2);
			Path.Combine(filePath, _contentDirectory, assetIdentifier);

			assetIdentifier = filePath;
		}

		FileStream fs = new FileStream();
		var result = fs.Open(assetIdentifier, .Open, .Read, .ReadWrite);

		if (result case .Err)
			return null;

		return fs;*/
	}

	public AssetHandle ManageAsset(Asset asset)
	{
		Log.EngineLogger.AssertDebug(asset.Handle == .Invalid, "Asset is already managed.");
		Log.EngineLogger.AssertDebug(asset.ContentManager == null, "Asset is already managed.");

		AssetHandle handle = .();

		// Generate until we find a unique key (shouldn't happen too often)
		while (_handleToAsset.ContainsKey(handle))
		{
			handle = .();
			// TODO: perhaps test how often this happens.
			// If this happens too often we could use a different random generator
		}

		//_handles.Add(asset.Identifier, handle);
		_handleToAsset.Add(handle, asset);

		asset.[Friend]_contentManager = this;
		asset.[Friend]_handle = handle;
		asset.AddRef();

		return handle;
	}

	public void UnmanageAsset(AssetHandle handle)
	{
		//Log.EngineLogger.AssertDebug(_handles.ContainsValue(handle), "Handle isn't managed by this content manager.");
		Log.EngineLogger.AssertDebug(_handleToAsset.ContainsKey(handle), "Handle doesn't correspond to an asset.");

		Asset asset = _handleToAsset[handle];

		if (_identiferToHandle.ContainsKey(asset.Identifier))
			_identiferToHandle.Remove(asset.Identifier);

		_handleToAsset.Remove(handle);
		asset.[Friend]_contentManager = null;

		asset.ReleaseRef();
	}

	/// This will unregister all assets from this content manager.
	/// Note: This will not release any assets.
	private void UnmanageAllAssets()
	{
		for (let (_, assetHandle) in _identiferToHandle)
		{
			UnmanageAsset(assetHandle);
		}
	}

	public void UpdateAssetIdentifier(Asset asset, StringView oldIdentifier, StringView newIdentifier)
	{
		// TODO: this is much harder with asste handles that are basically hashed identifiers!

		Runtime.NotImplemented();

		if (oldIdentifier == newIdentifier)
			return;

		Log.EngineLogger.Assert(_identiferToHandle.ContainsKey(newIdentifier), "An asset with the same identifier is already managed by this content manager.");

		// Since all we do in order to track assets is add them to a dictionary we can simply unmanage and manage it again.
		//UnmanageAsset(asset);
		//ManageAsset(asset);
	}
}