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
}

class AssetFile
{
	private EditorContentManager _contentManager;

	private String _path;
	private String _assetConfigPath;

	private AssetConfig _assetConfig ~ delete _;

	private bool _isDirectory;

	public bool IsDirectory => _isDirectory;

	public StringView FilePath => _path;

	public const String ConfigFileExtension = ".ass";

	public AssetConfig AssetConfig => _assetConfig;

	[AllowAppend]
	public this(EditorContentManager contentManager, StringView path, bool isDirectory)
	{
		String pathBuffer = append String(path);
		String configPathBuffer = append String(path.Length + ConfigFileExtension.Length);

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

	private void CreateDefaultAssetLoader()
	{
		String fileExtension = Path.GetExtension(_path, .. scope .());
		
		_assetConfig = new AssetConfig();
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

	private void SaveAssetConfig()
	{
		gBonEnv.serializeFlags |= .Verbose;

		Bon.SerializeIntoFile(_assetConfig, _assetConfigPath);
	}
}