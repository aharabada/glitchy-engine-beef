using Bon;
using GlitchyEngine.Content;
using System;
using System.Collections;
using System.IO;
using GlitchyEngine;
using GlitchyEngine.Renderer;

namespace GlitchyEditor.Assets;

class MaterialAssetPropertiesEditor : AssetPropertiesEditor
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
class MaterialAssetLoaderConfig : AssetLoaderConfig
{
	
}

[BonTarget]
class MaterialFile
{
	public String Effect ~ delete _;

	public Dictionary<String, String> Textures ~ DeleteDictionaryAndKeysAndValues!(_);
	//public Dictionary<String, Object> Variables;
}

class MaterialAssetLoader : IAssetLoader //, IReloadingAssetLoader
{
	private static readonly List<StringView> _fileExtensions = new .(){".mat"} ~ delete _;

	public static List<StringView> FileExtensions => _fileExtensions;

	public AssetLoaderConfig GetDefaultConfig()
	{
		return new ModelAssetLoaderConfig();
	}

	public Asset LoadAsset(Stream file, AssetLoaderConfig config, StringView? subAsset, IContentManager contentManager)
	{
		StreamReader reader = scope .(file);

		String text = scope .();

		reader.ReadToEnd(text);

		MaterialFile materialFile = scope .();

		var result = Bon.Deserialize<MaterialFile>(ref materialFile, text);

		if (result case .Err)
		{
			Log.EngineLogger.Error("Failed to load material.");
			return null;
			// TODO: return error material
		}

		Effect fx = new Effect(materialFile.Effect);

		Material material = new Material(fx);

		for (let (slotName, textureIdentifier) in materialFile.Textures)
		{
			Texture texture = contentManager.LoadAsset(textureIdentifier) as Texture;

			if (texture == null)
			{
				Log.EngineLogger.Error("Failed to load texture.");
				// TODO: LoadAsset should return an error texture.
			}

			material.SetTexture(slotName, texture);
		}

		fx.ReleaseRef();

		/*for (let (slotName, textureIdentifier) in materialFile.Variables)
		{
			if (texture == null)
			{
				Log.EngineLogger.Error("Failed to load texture.");
				// TODO: LoadAsset should return an error texture.
			}

			material.SetVariable(slotName, );
		}*/

		return material; //ModelLoader.LoadMesh(file, subAsset.Value, 0);
	}
}