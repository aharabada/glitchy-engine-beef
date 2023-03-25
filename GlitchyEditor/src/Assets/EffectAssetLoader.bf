using Bon;
using GlitchyEngine.Content;
using System;
using System.Collections;
using System.IO;
using GlitchyEngine;
using GlitchyEngine.Renderer;

namespace GlitchyEditor.Assets;

class EffectAssetPropertiesEditor : AssetPropertiesEditor
{
	public this(AssetFile asset) : base(asset)
	{

	}

	public override void ShowEditor()
	{

	}

	public static AssetPropertiesEditor Factory(AssetFile assetFile)
	{
		return new Self(assetFile);
	}
}

[BonTarget, BonPolyRegister]
class EffectAssetLoaderConfig : AssetLoaderConfig
{
	
}

class EffectAssetLoader : IAssetLoader //, IReloadingAssetLoader
{
	private static readonly List<StringView> _fileExtensions = new .(){".hlsl"} ~ delete _;

	public static List<StringView> FileExtensions => _fileExtensions;

	public AssetLoaderConfig GetDefaultConfig()
	{
		return new EffectAssetLoaderConfig();
	}

	public Asset LoadAsset(Stream file, AssetLoaderConfig config, StringView assetIdentifier, StringView? subAsset, IContentManager contentManager)
	{
		Effect effect = new Effect(file, assetIdentifier, contentManager);

		return effect;
	}

	public Asset GetPlaceholderAsset(Type assetType)
	{
		return default;
	}

	public Asset GetErrorAsset(Type assetType)
	{
		return default;
	}
}