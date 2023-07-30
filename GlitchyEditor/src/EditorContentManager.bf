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
using System.Threading.Tasks;
using internal GlitchyEngine.Content.Asset;

namespace GlitchyEditor;

class EditorContentManager : IContentManager
{
	private append String _resourcesDirectory = .();
	private append String _assetsDirectory = .();

	public StringView ResourcesDirectory => _resourcesDirectory;
	public StringView AssetDirectory => _assetsDirectory;
	
	private append Dictionary<StringView, AssetHandle> _identiferToHandle = .(); // TODO: Check if all resources are unloaded

	private append Dictionary<AssetHandle, Asset> _handleToAsset = .();

	private append AssetHierarchy _assetHierarchy = .(this);

	public AssetHierarchy AssetHierarchy => _assetHierarchy;

	private append List<AssetHandle> _reloadQueue = .();

	public this()
	{
		_assetHierarchy.OnFileContentChanged.Add(new => OnFileContentChanged);
		_assetHierarchy.OnFileRenamed.Add(new => OnFileRenamed);
	}

	public ~this()
	{
		UnmanageAllAssets();
	}

	private void OnFileContentChanged(AssetNode assetNode)
	{
		// Asset isn't loaded so we don't need to reload it.
		if (assetNode.AssetFile.LoadedAsset == null)
			return;

		_reloadQueue.Add(assetNode.AssetFile.LoadedAsset.Handle);
	}
	
	public void OnFileRenamed(AssetNode assetNode, StringView oldIdentifier)
	{
		// Asset isn't loaded so we don't need to reload it.
		if (assetNode.AssetFile.LoadedAsset == null)
			return;

		Asset asset = assetNode.AssetFile.LoadedAsset;

		_identiferToHandle.Remove(oldIdentifier);
		asset.Identifier = assetNode.AssetFile.Identifier;
		_identiferToHandle.Add(asset.Identifier, asset.Handle);
	}

	public void SetResourcesDirectory(StringView fileName)
	{
		_resourcesDirectory.Set(fileName);
		Path.Fixup(_resourcesDirectory);

		_assetHierarchy.SetResourcesDirectory(_resourcesDirectory);
	}

	public void SetAssetDirectory(StringView fileName)
	{
		_assetsDirectory.Set(fileName);
		Path.Fixup(_assetsDirectory);

		_assetHierarchy.SetAssetsDirectory(_assetsDirectory);
	}

	public void Update()
	{
		SwapInLoadedAssets();

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

	/// Replaces placeholders with the loaded assets
	private void SwapInLoadedAssets()
	{
		// Don't take the lock if we have nothing to do.
		if (_finishedEntries.Count == 0)
			return;

		using (_finishedEntriesLock.Enter())
		{
			while (_finishedEntries.Count > 0)
			{
				let (placeholder, asset) = _finishedEntries[0];

				delete placeholder.LoadingTask;

				if (asset == null)
					placeholder.PlaceholderType = .Error;
				else
				{
					// TODO: I'm not sure whether AssetFiles are guaranteed to persist.
					// Get the reference here because placeholder wont survive SwapAsset.
					AssetFile file = placeholder.AssetFile;
					file.[Friend]_loadedAsset = asset;

					SwapAsset(placeholder, asset);
					// SwapAsset increases RefCount, but this scope also holds a reference.
					asset.ReleaseRef();
				}

				_finishedEntries.RemoveAtFast(0);
			}
		}
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
		// Log.EngineLogger.AssertDebug(!_assetLoaders.Any((l) => l.GetType() == typeof(T)), "Asset loader already registered.");

		T assetLoader = new T();

		_assetLoaders.Add(assetLoader);

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

		if (var placeholder = asset as PlaceholderAsset)
		{
			if (placeholder.PlaceholderType == .Loading)
				return placeholder.AssetLoader.GetPlaceholderAsset(assetType);
			else if (placeholder.PlaceholderType == .Error)
				return placeholder.AssetLoader.GetErrorAsset(assetType);
		}

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
		Debug.Profiler.ProfileResourceFunction!();
		
		Asset oldAsset = null;

		if (!_handleToAsset.TryGetValue(handle, out oldAsset))
		{
			Log.EngineLogger.Error("Can't reload! No asset exists for handle.");

			return;
		}

		Log.EngineLogger.AssertDebug(oldAsset != null);

		StringView oldIdentifier = oldAsset.Identifier;

		GetResourceAndSubassetName(oldIdentifier, let resourceName, let subassetName);
		
		String filePath = scope .();
		GetResourceFilePath(resourceName, filePath);

		Result<TreeNode<AssetNode>> resultNode = AssetHierarchy.GetNodeFromPath(filePath);

		if (resultNode case .Err)
		{
			Log.EngineLogger.Error($"Could not find asset \"{filePath}\".");
			return;
		}

		AssetFile file = resultNode->Value.AssetFile;
		
		IAssetLoader assetLoader = GetAssetLoader(file);

		Stream stream = GetStream(filePath);

		// TODO: Add async loading!
		Asset loadedAsset = assetLoader.LoadAsset(stream, file.AssetConfig.Config, resourceName, subassetName, this);

		delete stream;

		if (loadedAsset == null)
			return;
		
		file.[Friend]_loadedAsset = loadedAsset;

		SwapAsset(oldAsset, loadedAsset);
		// SwapAsset increases RefCount, but this scope also holds a reference.
		loadedAsset.ReleaseRef();
	}

	/// Returns the resource name and, if it exists, the subasset name.
	private void GetResourceAndSubassetName(StringView identifier, out StringView resourceName, out StringView? subassetName)
	{
		int poundIndex = identifier.IndexOf('#');

		resourceName = (poundIndex != -1) ? identifier.Substring(0, poundIndex) : identifier;
		subassetName = (poundIndex != -1) ? identifier.Substring(poundIndex + 1) : null;
	}

	private void GetResourceFilePath(StringView resourceName, String filePath)
	{
		Path.Combine(filePath, _assetsDirectory, resourceName);

		Path.Fixup(filePath);
	}

	private enum PlaceholderType
	{
		Loading,
		Error
	}

	private class PlaceholderAsset : Asset
	{
		public AssetFile AssetFile {get; private set;}
		public Task LoadingTask {get;set;}
		public IAssetLoader AssetLoader {get; private set;}
		public PlaceholderType PlaceholderType {get; set;}

		public this(AssetFile assetFile, IAssetLoader assetLoader, PlaceholderType placeholderType)
		{
			AssetFile = assetFile;
			AssetLoader = assetLoader;
			PlaceholderType = placeholderType;
		}
	}

	private append Monitor _finishedEntriesLock = .();
	private append List<(PlaceholderAsset placeholder, Asset newAsset)> _finishedEntries = .();

	private class MissingAsset : Asset {}

	public AssetHandle LoadAsset(StringView identifier, bool blocking = false)
	{
		Debug.Profiler.ProfileResourceFunction!();

		// It's valid to request no entity, but no entity is obviously invalid.
		if (identifier.IsWhiteSpace)
			return .Invalid;
		
		String fixedIdentifier = scope String(identifier);
		AssetIdentifier.Fixup(fixedIdentifier);

		if (_identiferToHandle.TryGetValue(fixedIdentifier, let asset))
			return asset;

		GetResourceAndSubassetName(fixedIdentifier, let resourceName, let subassetName);

		Result<TreeNode<AssetNode>> resultNode = AssetHierarchy.GetNodeFromIdentifier(fixedIdentifier);

		if (resultNode case .Err)
		{
			Log.EngineLogger.Error($"Could not find asset \"{fixedIdentifier}\".");
			return .Invalid;
		}
		
		String filePath = scope String(resultNode->Value.Path);

		AssetFile file = resultNode->Value.AssetFile;
		
		IAssetLoader assetLoader = GetAssetLoader(file);

		// TODO: what are we supposed to do if we don't find a loader? Surely not crash...
		//Log.EngineLogger.AssertDebug(assetLoader != null);
		if (assetLoader == null)
		{
			Log.EngineLogger.Error($"No asset loader registered for asset {identifier}.");
			return .Invalid;
		}

		Asset loadedAsset;

		// TODO: Support lazy loading for all asset types
		if (!(assetLoader is EditorTextureAssetLoader) || blocking)
		{
			Stream stream = OpenStream(filePath, true);

			loadedAsset = assetLoader.LoadAsset(stream, file.AssetConfig.Config, resourceName, subassetName, this);

			delete stream;

			if (loadedAsset == null)
				return .Invalid;
		}
		else
		{
			PlaceholderAsset placeholder = new PlaceholderAsset(file, assetLoader, .Loading);

			String filePath2 = new String(filePath);
			String newResourceName = new String(resourceName);
			String newSesourceName = subassetName == null ? null : new String(subassetName.Value);

			placeholder.LoadingTask = new Task(new () => {
				AsyncLoadAsset(placeholder, filePath2, assetLoader, file,
					newResourceName, newSesourceName);
			});

			ThreadPool.QueueUserWorkItem(placeholder.LoadingTask);

			loadedAsset = placeholder;
		}

		loadedAsset.Identifier = fixedIdentifier;
		AssetHandle handle = ManageAsset(loadedAsset);
		// ManageAsset increases RefCount, but this scope also holds a reference.
		loadedAsset.ReleaseRef();

		// Add to Identifier -> Handle map
		_identiferToHandle.Add(loadedAsset.Identifier, handle);

		file.[Friend]_loadedAsset = loadedAsset;

		return handle;
	}

	private void AsyncLoadAsset(PlaceholderAsset placeholder, String filePath, IAssetLoader assetLoader, AssetFile file, String resourceName, String subassetName)
	{
		Debug.Profiler.ProfileResourceFunction!();
		
		Stream stream = OpenStream(filePath, true);

		Asset loadedAsset = assetLoader.LoadAsset(stream, file.AssetConfig.Config, resourceName, subassetName, this);

		delete stream;
		delete filePath;
		delete resourceName;
		delete subassetName;

		using (_finishedEntriesLock.Enter())
		{
			_finishedEntries.Add((placeholder, loadedAsset));
		}
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

	private Stream OpenStream(StringView fileName, bool openOnly)
	{
		FileStream fs = new FileStream();

		FileMode fileMode = openOnly ? FileMode.Open : FileMode.OpenOrCreate;

		var result = fs.Open(fileName, fileMode, openOnly ? .Read : .ReadWrite, .ReadWrite);

		if (result case .Err)
			return null;

		return fs;
	}

	/// Returns a file stream for the given assetIdentifier
	public Stream GetStream(StringView assetIdentifier)
	{
		String fixuppedIdentifier = scope .(assetIdentifier);
		AssetIdentifier.Fixup(fixuppedIdentifier);

		var node = _assetHierarchy.GetNodeFromIdentifier(fixuppedIdentifier);

		if (node case .Err)
		{
			Log.EngineLogger.Error($"Could not find asset node \"{assetIdentifier}\".");
			return null;
		}

		return OpenStream(node->Value.Path, true);
	}

	public AssetHandle ManageAsset(Asset asset)
	{
		Log.EngineLogger.AssertDebug(asset.Handle == .Invalid, "Asset is already managed.");
		Log.EngineLogger.AssertDebug(asset.ContentManager == null, "Asset is already managed.");

		AssetHandle handle = .();

		// Generate until we find a unique key (shouldn't happen too often)
		while (handle.IsInvalid || _handleToAsset.ContainsKey(handle))
		{
			handle = .();
			Log.EngineLogger.Trace("Handle was invalid or already taken.");
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

	private void SwapAsset(Asset oldAsset, Asset newAsset)
	{
		newAsset.Identifier = oldAsset.Identifier;
		newAsset._contentManager = this;
		newAsset._handle = oldAsset.Handle;

		_handleToAsset[oldAsset.Handle] = newAsset;

		if (_identiferToHandle.ContainsKey(oldAsset.Identifier))
		{
			_identiferToHandle.Remove(oldAsset.Identifier);
			_identiferToHandle.Add(newAsset.Identifier, newAsset.Handle);
		}

		newAsset.AddRef();
		oldAsset.ReleaseRef();
	}

	public void UnmanageAsset(AssetHandle handle)
	{
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
		for (let (handle, _) in _handleToAsset)
		{
			UnmanageAsset(handle);
		}
	}

	public void AssetMoved(Asset asset, StringView oldIdentifier, StringView newIdentifier)
	{
		Runtime.NotImplemented();

		if (oldIdentifier == newIdentifier)
			return;

		Log.EngineLogger.Assert(_identiferToHandle.ContainsKey(newIdentifier), "An asset with the same identifier is already managed by this content manager.");

		// Since all we do in order to track assets is add them to a dictionary we can simply unmanage and manage it again.
		//UnmanageAsset(asset);
		//ManageAsset(asset);
	}
}