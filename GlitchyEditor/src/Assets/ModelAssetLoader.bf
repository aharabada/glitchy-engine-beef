using Bon;
using GlitchyEngine.Content;
using System;
using System.Collections;
using System.IO;
using GlitchyEngine;

namespace GlitchyEditor.Assets;

class ModelAssetPropertiesEditor : AssetPropertiesEditor
{
	public this(AssetFile asset) : base(asset)
	{

	}

	public override void ShowEditor()
	{

	}

	public static AssetPropertiesEditor Factory(AssetFile assetFile)
	{
		return new ModelAssetPropertiesEditor(assetFile);
	}
}

[BonTarget, BonPolyRegister]
class ModelAssetLoaderConfig : AssetLoaderConfig
{
	
}

class ModelAssetLoader : IAssetLoader //, IReloadingAssetLoader
{
	private static readonly List<StringView> _fileExtensions = new .(){".gltf", ".glb"} ~ delete _;

	public static List<StringView> FileExtensions => _fileExtensions;

	public AssetLoaderConfig GetDefaultConfig()
	{
		return new ModelAssetLoaderConfig();
	}

	public Asset LoadAsset(Stream file, AssetLoaderConfig config, StringView? subAsset, IContentManager contentManager)
	{
		Log.EngineLogger.Assert(subAsset != null);

		return ModelLoader.LoadMesh(file, subAsset.Value, 0);
	}
}