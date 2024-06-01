using System;
using GlitchyEngine;
using System.IO;
using Bon;
using GlitchyEngine.Content;
using GlitchyEditor.Assets;
using GlitchyEditor.Assets.Importers;

namespace GlitchyEditor;

[BonTarget]
class AssetConfig
{
    [BonIgnore]
	public bool IgnoreFile = false;

	[BonInclude]
	public String AssetLoader ~ delete _;

	[BonInclude]
	public AssetLoaderConfig Config ~ delete _;
	
	[BonInclude]
	public String Importer ~ delete _;
	[BonInclude]
	public AssetImporterConfig ImporterConfig ~ delete _;
	[BonInclude]
	public String Processor ~ delete _;
	[BonInclude]
	public AssetProcessorConfig ProcessorConfig ~ delete _;
	[BonInclude]
	public String Exporter ~ delete _;
	[BonInclude]
	public AssetExporterConfig ExporterConfig ~ delete _;

	[BonInclude]
	public AssetHandle AssetHandle = .Invalid;
}

/// Represents an unprocessed asset as it lies in the asset hierarchy.
class AssetFile
{
	private EditorContentManager _contentManager;

	private String _assetConfigPath ~ delete:append _;
	private AssetNode _assetFile;

	private AssetConfig _assetConfig ~ delete _;

	private Asset _loadedAsset;

	private DateTime _lastAssetEditTime;
	private DateTime _lastConfigEditTime;

	public AssetNode AssetFile => _assetFile;
	public StringView AssetConfigPath => _assetConfigPath;

	public const String ConfigFileExtension = ".ass";

	public AssetConfig AssetConfig => _assetConfig;

	public Asset LoadedAsset => _loadedAsset;

	public EditorContentManager ContentManager => _contentManager;

	public bool UseNewAssetPipeline => _assetConfig?.ImporterConfig != null;

	[AllowAppend]
	public this(EditorContentManager contentManager, AssetNode assetNode)
	{
		String configPathBuffer = append String(assetNode.Path.Length + ConfigFileExtension.Length);

		configPathBuffer..Append(assetNode.Path).Append(ConfigFileExtension);
		_assetConfigPath = configPathBuffer;

		_contentManager = contentManager;

		_assetFile = assetNode;

		_lastAssetEditTime = File.GetLastWriteTimeUtc(_assetFile.Path);
	}

	public static AssetFile LoadOrCreateAssetFile(EditorContentManager contentManager, AssetNode assetNode)
	{
		AssetFile assetFile = new AssetFile(contentManager, assetNode);

		assetFile.CheckForReprocessing();

		return assetFile;
	}

	public void CheckForReprocessing()
	{
		LoadOrCreateAssetConfig();

		// TODO: Remove this check once we only use the new processing pipeline
		if (!UseNewAssetPipeline)
			return;

		CachedAsset cacheEntry = _contentManager.AssetCache.GetCacheEntry(_assetConfig.AssetHandle);
		
		_lastAssetEditTime = File.GetLastWriteTimeUtc(_assetFile.Path);
		_lastConfigEditTime = File.GetLastWriteTimeUtc(_assetConfigPath);

		if (cacheEntry == null ||
			cacheEntry.CreationTimestamp < _lastAssetEditTime ||
			cacheEntry.CreationTimestamp < _lastConfigEditTime)
		{
			_contentManager.AssetConverter.QueueForProcessing(this);
		}
	}

	/// Loads the asset config (.ass) file or creates it.
	private void LoadOrCreateAssetConfig()
	{
		if (File.Exists(_assetConfigPath))
		{
			LoadAssetConfig();
		}
		else if (_assetConfig == null)
		{
			CreateDefaultAssetLoader();
		}

		_lastConfigEditTime = File.GetLastWriteTimeUtc(_assetConfigPath);
	}

	private void GenerateAssetHandle()
	{
		_assetConfig.AssetHandle = .();
	}

	private void CreateDefaultAssetLoader()
	{
		String fileExtension = Path.GetExtension(_assetFile.Path, .. scope .());

		Log.EngineLogger.Info($"Created config for {_assetFile.Path}");

		_assetConfig = new AssetConfig();
		
		GenerateAssetHandle();

		var assetPipeline = _contentManager.GetDefaultProcessors(fileExtension);

		// TODO!
		//if (assetPipeline case .Err)
		//	return;

		var assetLoader = _contentManager.GetDefaultAssetLoader(fileExtension);

		// We don't have a loader -> we don't need a config
		if (assetLoader == null)
			return;

		_assetConfig.AssetLoader = new String();
		assetLoader.GetType().GetName(_assetConfig.AssetLoader);

		_assetConfig.Config = assetLoader?.GetDefaultConfig();
		_assetConfig.Config?.[Friend]_changed = true;

		_assetConfig.Importer = new String();
		assetPipeline?.Importer?.GetType()?.GetName(_assetConfig.Importer);
		_assetConfig.ImporterConfig = assetPipeline?.Importer.CreateDefaultConfig();

		_assetConfig.Processor = new String();
		assetPipeline?.Processor?.GetType()?.GetName(_assetConfig.Processor);
		_assetConfig.ProcessorConfig = assetPipeline?.Processor.CreateDefaultConfig();

		_assetConfig.Exporter = new String();
		assetPipeline?.Exporter?.GetType()?.GetName(_assetConfig.Exporter);
		_assetConfig.ExporterConfig = assetPipeline?.Exporter.CreateDefaultConfig();

		SaveAssetConfig();
	}

	private void LoadAssetConfig()
	{
		AssetConfig newAssetConfig = new AssetConfig();

		if (Bon.DeserializeFromFile(ref newAssetConfig, _assetConfigPath) case .Err)
		{
			Log.EngineLogger.Error($"Failed to load asset config {_assetConfigPath}");

			delete newAssetConfig;

			return;
		}

		delete _assetConfig;
		_assetConfig = newAssetConfig;
	}

	public void SaveAssetConfig()
	{
		//BonEnvironment bonEnv = scope .();

		var oldFlags = gBonEnv.serializeFlags;

		gBonEnv.serializeFlags |= .IncludeDefault | .Verbose;

		Bon.SerializeIntoFile(_assetConfig, _assetConfigPath);

		_assetConfig.Config?.[Friend]_changed = false;

		gBonEnv.serializeFlags = oldFlags;
	}
}