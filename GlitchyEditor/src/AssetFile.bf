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

		assetFile.LoadOrCreateAssetConfig();

		// TODO: Remove this check once we only use the new processing pipeline
		if (assetFile._assetConfig.ImporterConfig != null)
		{
			CachedAsset cacheEntry = assetFile._contentManager.AssetCache.GetCacheEntry(assetFile._assetConfig.AssetHandle);
	
			if (cacheEntry == null ||
				cacheEntry.CreationTimestamp < assetFile._lastAssetEditTime ||
				cacheEntry.CreationTimestamp < assetFile._lastConfigEditTime)
			{
				assetFile._contentManager.AssetConverter.QueueForProcessing(assetFile);
			}
		}

		return assetFile;
	}

	/// Loads the asset config (.ass) file or creates it.
	private void LoadOrCreateAssetConfig()
	{
		if (File.Exists(_assetConfigPath))
		{
			LoadAssetConfig();
		}
		else
		{
			CreateDefaultAssetLoader();
		}

		_lastAssetEditTime = File.GetLastWriteTimeUtc(_assetConfigPath);
	}

	private void GenerateAssetHandle()
	{
		_assetConfig.AssetHandle = .();
	}

	private void CreateDefaultAssetLoader()
	{
		String fileExtension = Path.GetExtension(_assetFile.Path, .. scope .());
		
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
		if (Bon.DeserializeFromFile(ref _assetConfig, _assetConfigPath) case .Err)
		{
			Log.EngineLogger.Error($"Failed to load asset config {_assetConfigPath}");

			// TODO: Handle failure of asset config loading
			Runtime.NotImplemented();
		}
	}

	public void SaveAssetConfig()
	{
		gBonEnv.serializeFlags |= .Verbose;

		Bon.SerializeIntoFile(_assetConfig, _assetConfigPath);

		_assetConfig.Config.[Friend]_changed = false;
	}
}