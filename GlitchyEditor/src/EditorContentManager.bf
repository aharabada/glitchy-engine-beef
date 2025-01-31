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
using GlitchyEditor.Assets.Importers;
using GlitchyEngine.Core;
using GlitchyEngine.Content.Loaders;

using internal GlitchyEngine.Content.Asset;

namespace GlitchyEditor;

class EditorContentManager : IContentManager
{
	private append String _resourcesDirectory = .();
	private append String _assetsDirectory = .();
	
	private append Dictionary<StringView, AssetHandle> _identiferToHandle = .(); // TODO: Check if all resources are unloaded

	private append Dictionary<AssetHandle, Asset> _handleToAsset = .();

	private append AssetHierarchy _assetHierarchy = .(this);
	private append AssetCache _assetCache = .(this);
	private append AssetConverter _assetConverter = .(this);

	private append List<AssetHandle> _reloadQueue = .();
	
	public StringView ResourcesDirectory => _resourcesDirectory;
	public StringView AssetDirectory => _assetsDirectory;
	public AssetHierarchy AssetHierarchy => _assetHierarchy;
	public AssetCache AssetCache => _assetCache;
	public AssetConverter AssetConverter => _assetConverter;

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
		if (assetNode.AssetFile?.LoadedAsset == null)
			return;

		QueueAssetReload(assetNode.AssetFile.LoadedAsset.Handle);
	}

	public void QueueAssetReload(AssetHandle assetHandle)
	{
		// If the asset isn't loaded we don't care about reloading it. Also don't reload twice
		if (!_handleToAsset.ContainsKey(assetHandle) || _reloadQueue.Contains(assetHandle))
			return;

		_reloadQueue.Add(assetHandle);
	}

	public void OnFileRenamed(AssetNode assetNode, StringView oldIdentifier)
	{
		// Asset isn't loaded so we don't need to reload it.
		if (assetNode.AssetFile?.LoadedAsset == null)
			return;

		Asset asset = assetNode.AssetFile.LoadedAsset;

		_identiferToHandle.Remove(oldIdentifier);
		asset.Identifier = assetNode.Identifier;
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
	
	public void SetGlobalAssetCacheDirectory(StringView fileName)
	{
		_assetCache.SetGlobalCacheDirectory(fileName);
	}

	public void SetAssetCacheDirectory(StringView fileName)
	{
		_assetCache.SetProjectCacheDirectory(fileName);
	}

	public void Update()
	{
		_assetConverter.Update();

		SwapInLoadedAssets();

		if (!_reloadQueue.IsEmpty)
		{
			for (AssetHandle handle in _reloadQueue)
			{
				ReloadAsset(handle);
			}
			_reloadQueue.Clear();
		}
	}

	/// Replaces placeholders with the loaded assets
	private void SwapInLoadedAssets()
	{
		// Don't take the lock if we have nothing to do.
		if (_finishedEntries.Count == 0 && _newFinishedEntries.Count == 0)
			return;

		using (_finishedEntriesLock.Enter())
		{
			// TODO: Get rid of old queue
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

			for (let (placeholder, loadedAsset) in _newFinishedEntries)
			{
				Log.EngineLogger.Trace($"Dequeue: {Internal.UnsafeCastToPtr(placeholder)} {placeholder.AssetHandle} {placeholder.RefCount}");

				placeholder.LoadingTask.Wait();

				delete placeholder.LoadingTask;
				placeholder.LoadingTask = null;

				if (loadedAsset == null)
					placeholder.PlaceholderType = .Error;
				else
				{
					Result<TreeNode<AssetNode>> assetNodeResult = _assetHierarchy.GetNodeFromAssetHandle(placeholder.Handle);
					
					if (assetNodeResult case .Ok(let assetNode))
					{
						assetNode->AssetFile.[Friend]_loadedAsset = loadedAsset;
	
						SwapAsset(placeholder, loadedAsset);
					}
					else
					{
						Log.EngineLogger.Error($"Could not find asset node for asset with handle \"{placeholder.AssetHandle}\" while swapping in asset.");
						placeholder.PlaceholderType = .Error;
					}

					// SwapAsset increases RefCount, but this scope also holds a reference.
					loadedAsset.ReleaseRef();
				}
			}

			_newFinishedEntries.Clear();
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
		delete:append _;
	};

	private append List<IAssetImporter> _assetImporters = .() ~ ClearAndDeleteItems!(_);
	private append Dictionary<StringView, IAssetImporter> _extensionToAssetImporter = .();
	private append Dictionary<Type, IAssetProcessor> _importedResourceToAssetProcessor = .() ~ ClearDictionaryAndDeleteValues!(_);
	private append Dictionary<AssetType, IAssetExporter> _assetTypeToAssetExporter = .() ~ ClearDictionaryAndDeleteValues!(_);

	public void RegisterAssetLoader<T>() where T : new, class, IAssetLoader
	{
		// Log.EngineLogger.AssertDebug(!_assetLoaders.Any((l) => l.GetType() == typeof(T)), "Asset loader already registered.");

		T assetLoader = new T();

		_assetLoaders.Add(assetLoader);

		for (StringView ext in T.FileExtensions)
			_supportedExtensions.Add(new String(ext));
	}

	public void RegisterAssetImporter<T>() where T : new, class, IAssetImporter
	{
		T assetImporter = new T();
		_assetImporters.Add(assetImporter);

		for (StringView ext in T.FileExtensions)
		{
			String fileExtension = new String(ext);
			_supportedExtensions.Add(fileExtension);
			_extensionToAssetImporter.Add(fileExtension, assetImporter);
		}
	}

	public void RegisterAssetProcessor<T>() where T : new, class, IAssetProcessor
	{
		Log.EngineLogger.AssertDebug(!_importedResourceToAssetProcessor.ContainsKey(T.ProcessedAssetType), "Cannot register multiple processor for the same imported resource type.");

		_importedResourceToAssetProcessor.Add(T.ProcessedAssetType, new T());
	}

	public void RegisterAssetExporter<T>() where T : new, class, IAssetExporter
	{
		Log.EngineLogger.AssertDebug(!_assetTypeToAssetExporter.ContainsKey(T.ExportedAssetType), "Cannot register multiple exporters for one asset type.");

		_assetTypeToAssetExporter.Add(T.ExportedAssetType, new T());
	}

	public IAssetImporter GetAssetImporter(StringView fileExtension)
	{
		if (_extensionToAssetImporter.TryGetValue(fileExtension, let importer))
		{
			return importer;
		}

		return null;
	}
	
	public IAssetImporter GetAssetImporter(AssetFile file)
	{
		IAssetImporter result = null;

		String typeName = scope .(128);

		for (IAssetImporter importer in _extensionToAssetImporter.Values)
		{
			importer.GetType().GetName(typeName..Clear());

			if (typeName == file.AssetConfig.Importer)
			{
				result = importer;
				break;
			}
		}

		return result;
	}

	public IAssetProcessor GetAssetProcessor(Type importedResourceType)
	{
		if (_importedResourceToAssetProcessor.TryGetValue(importedResourceType, let processor))
		{
			return processor;
		}

		return null;
	}

	public IAssetExporter GetAssetExporter(AssetType assetType)
	{
		if (_assetTypeToAssetExporter.TryGetValue(assetType, let exporter))
		{
			return exporter;
		}

		return null;
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

	public Asset GetAsset(Type assetType, AssetHandle handle, bool blocking = false)
	{
		Asset asset = null;

		if (!_handleToAsset.TryGetValue(handle, out asset))
		{
			LoadAsset(handle, blocking);
		}

		if (var placeholder = asset as PlaceholderAsset)
		{
			if (placeholder.PlaceholderType == .Loading)
				return placeholder.AssetLoader.GetPlaceholderAsset(assetType);
			else if (placeholder.PlaceholderType == .Error)
				return placeholder.AssetLoader.GetErrorAsset(assetType);
		}
		
		if (var placeholder = asset as NewPlaceholderAsset)
		{
			return GetPlaceholderAsset(assetType, placeholder.PlaceholderType);
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

	private Asset GetPlaceholderAsset(Type assetType, PlaceholderType placeholderType)
	{
		switch (assetType)
		{
		case typeof(Texture2D):
			if (placeholderType == .Loading)
			{
				AssetHandle handle = LoadAsset("Resources/Textures/PlaceholderTexture2D.png", true);
				return GetAsset(null, handle);
			}
			else if (placeholderType == .Error)
			{
				AssetHandle handle = LoadAsset("Resources/Textures/ErrorTexture2D.png", true);
				return GetAsset(null, handle);
			}
		}

		return null;
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

		Result<TreeNode<AssetNode>> resultNode = AssetHierarchy.GetNodeFromAssetHandle(handle);

		if (resultNode case .Err)
		{
			Log.EngineLogger.Error($"Could not find asset node for asset \"{oldAsset.Identifier}\".");
			return;
		}

		AssetNode assetNode = resultNode->Value;
		AssetFile file = assetNode.AssetFile;

		CachedAsset cacheEntry = _assetCache.GetCacheEntry(handle);

		Asset loadedAsset;

		// TODO: Remove this check once we no longer need the old stuff
		if (cacheEntry != null)
		{
			loadedAsset = LoadFromCache(handle, false);
		}
		else
		{
			IAssetLoader assetLoader = GetAssetLoader(file);
	
			Stream stream = OpenStream(assetNode.Path, true);
			
			StringView oldIdentifier = oldAsset.Identifier;

			GetResourceAndSubassetName(oldIdentifier, let resourceName, let subassetName);

			// TODO: Add async loading!
			loadedAsset = assetLoader.LoadAsset(stream, file.AssetConfig.Config, resourceName, subassetName, this);
		
			delete stream;
		}

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

	private class NewPlaceholderAsset : Asset
	{
		public AssetHandle AssetHandle {get; private set;}
		public Task LoadingTask {get;set;}
		public PlaceholderType PlaceholderType {get; set;}

		public this(AssetHandle assetHandle, PlaceholderType placeholderType)
		{
			AssetHandle = assetHandle;
			PlaceholderType = placeholderType;
		}

		public ~this()
		{
			Log.EngineLogger.Trace($"Deleted: {Internal.UnsafeCastToPtr(this)}");
		}
	}

	private append Monitor _finishedEntriesLock = .();
	private append List<(PlaceholderAsset placeholder, Asset newAsset)> _finishedEntries = .();
	private append List<(NewPlaceholderAsset placeholder, Asset newAsset)> _newFinishedEntries = .();

	private class MissingAsset : Asset {}
	
	/// Loads the Asset that is represented by the given AssetHandle.
	/// @returns The AssetHandle of the loaded asset or .Invalid if no asset exists with the given handle.
	public AssetHandle LoadAsset(AssetHandle handle, bool blocking = false)
	{
		Debug.Profiler.ProfileResourceFunction!();

		if (handle.IsInvalid)
			return .Invalid;

		// If _handleToAsset contains handle, we for sure have an asset for it.
		if (_handleToAsset.ContainsKey(handle))
			return handle;

		Result<TreeNode<AssetNode>> resultNode = AssetHierarchy.GetNodeFromAssetHandle(handle);

		if (resultNode case .Err)
		{
			Log.EngineLogger.Error($"Could not find asset with handle {handle} in hierarchy.");
			return .Invalid;
		}
		
		AssetNode assetNode = resultNode->Value;
		AssetFile file = assetNode.AssetFile;

		Asset loadedAsset;

		// TODO: Remove this check once we no longer need the old stuff
		if (file.UseNewAssetPipeline)
		{
			loadedAsset = LoadFromCache(handle, blocking);
		}
		else
		{
			// else use the old mess...
	
			String filePath = scope String(resultNode->Value.Path);

			GetResourceAndSubassetName(assetNode.Identifier, let resourceName, let subassetName);

			IAssetLoader assetLoader = GetAssetLoader(file);

			//Log.EngineLogger.AssertDebug(assetLoader != null);
			if (assetLoader == null)
			{
				Log.EngineLogger.Error($"No asset loader registered for asset \"{resultNode->Value.Identifier}\" ({handle}).");
				return .Invalid;
			}

			// TODO: Support lazy loading for all asset types
			if (true || blocking)
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
		}
		
		using (_finishedEntriesLock.Enter())
		{
			loadedAsset.Identifier = assetNode.Identifier;
			loadedAsset.[Friend]_contentManager = this;
			loadedAsset.[Friend]_handle = handle;
	
			_handleToAsset.Add(handle, loadedAsset);
			_identiferToHandle.Add(loadedAsset.Identifier, handle);

			file.[Friend]_loadedAsset = loadedAsset;
		}

		return handle;
	}

	/// Loads the Asset with the given asset identifier
	public AssetHandle LoadAsset(StringView identifier, bool blocking = false)
	{
		Debug.Profiler.ProfileResourceFunction!();

		// It's valid to request no entity, but no entity is obviously invalid.
		if (identifier.IsWhiteSpace)
			return .Invalid;

		// We allow backslashes as well as forward slashes. Some Path stuff like /./ is also allowed.
		String fixedIdentifier = scope String(identifier);
		AssetIdentifier.Fixup(fixedIdentifier);

		// If we have an identifier -> handle mapping, we for sure have the asset and are done.
		if (_identiferToHandle.TryGetValue(fixedIdentifier, let asset))
			return asset;

		if (AssetHierarchy.GetNodeFromIdentifier(fixedIdentifier) case .Ok(let assetNode))
		{
			return LoadAsset(assetNode->AssetFile.AssetConfig.AssetHandle, blocking);
		}
		else
		{
			Log.EngineLogger.Error($"Could not get asset node for asset {fixedIdentifier}");

			return .Invalid;
		}
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

		Result<TreeNode<AssetNode>> assetNode = AssetHierarchy.GetNodeFromIdentifier(asset.Identifier);

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

		Stream stream = GetStream(asset.Identifier, false);

		assetSaver.EditorSaveAsset(stream, asset, file.AssetConfig.Config, resourceName, subassetName, this);

		// Trim off the end of the file.
		stream.SetLength(stream.Position);

		delete stream;

		return .Ok;
	}

	/// Saves the asset.
	public Result<void, SaveAssetError> SaveAssetToFile(Asset asset, StringView fileName)
	{
		if (asset == null)
			return .Err(.Unknown);

		//if (asset.Identifier.IsWhiteSpace)
		//	return .Err(.Unsavable);

		String fileAssetName = scope .();
		
		Path.GetFileNameWithoutExtension(fileName, fileAssetName);

		StringView assetName = fileAssetName;
		StringView? subassetName = null;

		if (!asset.Identifier.IsWhiteSpace)
			GetResourceAndSubassetName(asset.Identifier, out assetName, out subassetName);

		//if (subassetName != null)
		//{
			// TODO: should this ever be allowed? Couldn't we just save the entire asset?
			// Would this ever be necessary?
		//	Runtime.NotImplemented("Saving subassets is not currently allowed");
		//}

		//Result<TreeNode<AssetNode>> assetNode = AssetHierarchy.GetNodeFromIdentifier(asset.Identifier);

		//if (assetNode case .Err)
		//	return .Err(.PathNotFound);

		//AssetFile file = assetNode.Get()->AssetFile;

		String fileExtension = scope .();
		Path.GetExtension(fileName, fileExtension);

		IAssetLoader assetLoader = GetDefaultAssetLoader(fileExtension);//GetAssetLoader(asset.GetType());
		
		if (assetLoader == null)
		{
			Log.EngineLogger.Error($"No asset loader found for extension {fileExtension}!");
			return .Err(.Unsavable);
		}

		IAssetSaver assetSaver = assetLoader as IAssetSaver;

		if (assetSaver == null)
		{
			Log.EngineLogger.Error("The asset loader can't save!");
			return .Err(.Unsavable);
		}

		Stream stream = OpenStream(fileName, false);

		var config = assetLoader.GetDefaultConfig();

		assetSaver.EditorSaveAsset(stream, asset, config, assetName, subassetName, this);

		delete config;

		// Trim off the end of the file.
		stream.SetLength(stream.Position);

		delete stream;

		return .Ok;
	}

	// Returns a filestream for the given asset file path
	private Stream OpenStream(StringView fileName, bool readOnly)
	{
		FileStream fs = new FileStream();

		FileMode fileMode = readOnly ? FileMode.Open : FileMode.OpenOrCreate;

		var result = fs.Open(fileName, fileMode, readOnly ? .Read : .ReadWrite, .ReadWrite);

		if (result case .Err)
			return null;

		return fs;
	}

	/// Returns a file stream for the given assetIdentifier
	public Stream GetStream(StringView assetIdentifier, bool readOnly)
	{
		String fixuppedIdentifier = scope .(assetIdentifier);
		AssetIdentifier.Fixup(fixuppedIdentifier);

		var node = _assetHierarchy.GetNodeFromIdentifier(fixuppedIdentifier);

		if (node case .Err)
		{
			Log.EngineLogger.Error($"Could not find asset node \"{assetIdentifier}\".");
			return null;
		}

		return OpenStream(node->Value.Path, readOnly);
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
	
	// TODO: obviously use a map or something...
	TextureLoader textureLoader = new .() ~ delete _;
	SpriteLoader spriteLoader = new .() ~ delete _;
	ShaderLoader shaderLoader = new .() ~ delete _;
	MaterialLoader materialLoader = new .() ~ delete _;

	private IProcessedAssetLoader GetLoader(AssetType assetType)
	{
		switch (assetType)
		{
		case .Texture:
			return textureLoader;
		case .Sprite:
			return spriteLoader;
		case .Shader:
			return shaderLoader;
		case .Material:
			return materialLoader;
		default:
			return null;
		}
	}

	private Asset LoadFromCache(AssetHandle handle, bool isBlocking)
	{
		CachedAsset asset = _assetCache.GetCacheEntry(handle);

		if (asset == null)
		{
			TreeNode<AssetNode> assetNode = TrySilent!(AssetHierarchy.GetNodeFromAssetHandle(handle));
			
			_assetConverter.QueueForProcessing(assetNode->AssetFile, isBlocking);

			var isBlocking;
			isBlocking = true;

			if (isBlocking)
			{
				asset = _assetCache.GetCacheEntry(handle);

				Log.EngineLogger.Assert(asset != null, "Failed to load asset.");
			}
			else
			{
				return new NewPlaceholderAsset(asset.Handle, .Loading);
			}
		}

		Asset InternalLoad(CachedAsset cachedAsset)
		{
			Result<Stream> streamResult = _assetCache.OpenStream(cachedAsset);

			if (streamResult case .Ok(Stream dataStream))
			{
				defer { delete dataStream; }

				IProcessedAssetLoader loader = GetLoader(cachedAsset.AssetType);

				if (loader.Load(dataStream) case .Ok(let loadedAsset))
				{
					Log.EngineLogger.Trace($"Loaded asset");
					return loadedAsset;
				}
				else
				{
					TreeNode<AssetNode> assetNode = TrySilent!(AssetHierarchy.GetNodeFromAssetHandle(handle));
					Log.EngineLogger.Error($"Failed to load asset \"{assetNode->Identifier}\" ({cachedAsset.Handle}): Loading of cached file failed.");
				}
			}
			else
			{
				TreeNode<AssetNode> assetNode = TrySilent!(AssetHierarchy.GetNodeFromAssetHandle(handle));
				Log.EngineLogger.Error($"Failed to load asset \"{assetNode->Identifier}\" ({cachedAsset.Handle}): Could not open stream to cached file.");
			}
			
			Log.EngineLogger.Trace($"Made error placeholder");
			NewPlaceholderAsset placeholder = new NewPlaceholderAsset(asset.Handle, .Error);

			return placeholder;
		}

		var isBlocking;

		isBlocking = true;

		if (isBlocking)
			return InternalLoad(asset);
		else
		{
			NewPlaceholderAsset placeholder = new NewPlaceholderAsset(asset.Handle, .Loading);
			Log.EngineLogger.Trace($"Created: {Internal.UnsafeCastToPtr(placeholder)} {placeholder.AssetHandle} {placeholder.RefCount}");

			placeholder.LoadingTask = new Task(new () => {
				Log.EngineLogger.Trace($"Load: {Internal.UnsafeCastToPtr(placeholder)} {placeholder.AssetHandle} {placeholder.RefCount}");
				Asset loadedAsset = InternalLoad(asset);
				
				using (_finishedEntriesLock.Enter())
				{
					Log.EngineLogger.Trace($"Enqueue: {Internal.UnsafeCastToPtr(placeholder)} {placeholder.AssetHandle} {placeholder.RefCount}");
					_newFinishedEntries.Add((placeholder, loadedAsset));
				}
			});

			ThreadPool.QueueUserWorkItem(placeholder.LoadingTask);

			return placeholder;
		}
	}
}