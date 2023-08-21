using System;
using GlitchyEngine;
using System.IO;
using Bon;
using GlitchyEngine.Content;

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
	public AssetHandle AssetHandle = .Invalid;
}

class AssetFile
{
	private EditorContentManager _contentManager;

	private String _path;
	private String _identifier;
	private String _assetConfigPath ~ delete _;

	private AssetConfig _assetConfig ~ delete _;

	private bool _isDirectory;

	private Asset _loadedAsset;

	public bool IsDirectory => _isDirectory;

	public StringView FilePath => _path;
	public StringView Identifier => _identifier;
	public StringView AssetConfigPath => _assetConfigPath;

	public const String ConfigFileExtension = ".ass";

	public AssetConfig AssetConfig => _assetConfig;

	public Asset LoadedAsset => _loadedAsset;

	[AllowAppend]
	public this(EditorContentManager contentManager, StringView identifier, StringView path, bool isDirectory)
	{
		String identifierBuffer = append String(identifier);
		String pathBuffer = append String(path);
		String configPathBuffer = new String(path.Length + ConfigFileExtension.Length);

		_identifier = identifierBuffer;
		_path = pathBuffer;

		configPathBuffer..Append(path).Append(ConfigFileExtension);
		_assetConfigPath = configPathBuffer;

		_contentManager = contentManager;

		_isDirectory = isDirectory;

		Log.EngineLogger.AssertDebug(File.Exists(_path), "File doesn't exist.");

		FindAssetConfig();
	}

	// Loads the asset config (.ass) file or creates it.
	private void FindAssetConfig()
	{
		if (File.Exists(_assetConfigPath))
		{
			LoadAssetConfig();
		}
		else
		{
			CreateDefaultAssetLoader();
		}
	}

	private void GenerateAssetHandle()
	{
		_assetConfig.AssetHandle = .();
	}

	private void CreateDefaultAssetLoader()
	{
		String fileExtension = Path.GetExtension(_path, .. scope .());
		
		_assetConfig = new AssetConfig();
		
		GenerateAssetHandle();

		var assetLoader = _contentManager.GetDefaultAssetLoader(fileExtension);

		// We don't have a loader -> we don't need a config
		if (assetLoader == null)
			return;

		_assetConfig.AssetLoader = new String();
		assetLoader.GetType().GetName(_assetConfig.AssetLoader);

		_assetConfig.Config = assetLoader?.GetDefaultConfig();
		_assetConfig.Config?.[Friend]_changed = true;


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