using System;
using System.Collections;
using Bon;
using System.IO;
using GlitchyEngine;
using GlitchyEngine.Content;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using DirectXTK;

namespace GlitchyEditor.Assets;

[BonTarget, BonPolyRegister]
class EditorTextureAssetLoaderConfig : AssetLoaderConfig
{
	[BonInclude]
	private bool _generateMipMaps;

	[BonInclude]
	private SamplerStateDescription _samplerStateDescription = .();

	public bool GenerateMipMaps
	{
		get => _generateMipMaps;
		set => SetIfChanged(ref _generateMipMaps, value);
	}

	public SamplerStateDescription SamplerStateDescription
	{
		get => _samplerStateDescription;
		set => SetIfChanged(ref _samplerStateDescription, value);
	}
}

class EditorTextureAssetLoader : IAssetLoader
{
	private static readonly List<StringView> _fileExtensions = new .(){".png", ".dds"} ~ delete _; // ".jpg", ".bmp"

	public static List<StringView> FileExtensions => _fileExtensions;

	public AssetLoaderConfig GetDefaultConfig()
	{
		return new EditorTextureAssetLoaderConfig();
	}

	public IRefCounted LoadAsset(Stream data, AssetLoaderConfig config)
	{
		var config;

		if (config == null)
		{
			config = GetDefaultConfig();
			defer:: delete config;
		}

		Log.EngineLogger.AssertDebug(config is EditorTextureAssetLoaderConfig, "config has wrong type.");

		return LoadTexture(data, (EditorTextureAssetLoaderConfig)config);
	}
	
	const String PngMagicWord = "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A";
	const String DdsMagicWord = "DDS ";

	private static Texture LoadTexture(Stream data, EditorTextureAssetLoaderConfig config)
	{
		Debug.Profiler.ProfileResourceFunction!();

		var readResult = data.Read<char8[8]>();

		data.Position = 0;

		char8[8] magicWord;

		Texture texture = null;

		if (readResult case .Ok(out magicWord))
		{
			StringView strView = .(&magicWord, magicWord.Count);

			if (strView.StartsWith(PngMagicWord))
			{
				texture = LoadPng(data, config);
			}
			else if (strView.StartsWith(DdsMagicWord))
			{
				texture = LoadDds(data, config);
			}
			else
			{
				Runtime.FatalError("Unknown image format.");
			}
		}

		Log.EngineLogger.AssertDebug(texture != null);

		/*SamplerStateDescription samplerDesc = .()
		{
			MinFilter = config.MinFilter,
			MagFilter = config.MagFilter,
			MipFilter = config.MipFilter,
			AddressModeU = config.WrapModeU,
			AddressModeV = config.WrapModeV,
			AddressModeW = config.WrapModeW
		};*/

		SamplerState sam = SamplerStateManager.GetSampler(config.SamplerStateDescription);

		texture.SamplerState = sam;

		sam.ReleaseRef();

		return texture;
	}

	private static Texture LoadPng(Stream data, EditorTextureAssetLoaderConfig config)
	{
		Debug.Profiler.ProfileResourceFunction!();

		uint8[] pngData = new:ScopedAlloc! uint8[data.Length];

		var result = data.TryRead(pngData);

		if (result case .Err(let err))
		{
			Log.EngineLogger.Error($"Failed to read data from stream. Texture: Error: {err}");
		}

		uint8* rawData = ?;
		uint32 width = 0, height = 0;

		uint32 errorCode = LodePng.LodePng.Decode32(&rawData, &width, &height, pngData.Ptr, (.)pngData.Count);

		Log.EngineLogger.Assert(errorCode == 0, "Failed to load png File");

		// TODO: load as SRGB because PNGs are usually not stored as linear
		//Texture2DDesc desc = .(width, height, srgb? .R8G8B8A8_UNorm_SRGB : .R8G8B8A8_UNorm, 1, 1, .Immutable);
		Texture2DDesc desc = .(width, height, .R8G8B8A8_UNorm, 1, 1, .Immutable);
		Texture2D texture = new Texture2D(desc);
		texture.SetData<Color>((.)rawData);

		// TODO: Generate mip maps

		LodePng.LodePng.Free(rawData);

		return texture;
	}
	
	private static Texture LoadDds(Stream data, EditorTextureAssetLoaderConfig config)
	{
		Texture2D texture = new [Friend]Texture2D(data);

		return texture;
	}
}
