using System;
using System.Collections;
using System.IO;
using Bon;
using GlitchyEngine.Content;
using GlitchyEngine;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using GlitchyEditor.Assets.Processors;
using ImGui;

using static GlitchyEditor.Assets.Importers.LoadedTextureInfo;

namespace GlitchyEditor.Assets.Importers;

class ImportedTexture : ImportedResource
{
	//public TextureDimension TextureType;
	private List<LoadedSurface> _surfaces = new .() ~ delete _;
	private LoadedTextureInfo _textureInfo ~ delete _textureInfo.PixelData;

	public List<LoadedSurface> Surfaces => _surfaces;

	public ref LoadedTextureInfo TextureInfo => ref _textureInfo;

	public this(AssetIdentifier ownAssetIdentifier) : base(ownAssetIdentifier)
	{
	}
}

[BonTarget, BonPolyRegister]
class TextureImporterConfig : AssetImporterConfig
{
	[BonInclude]
	private bool _isSrgb;

	public bool IsSrgb
	{
		get => _isSrgb;
		set => SetIfChanged(ref _isSrgb, value);
	}

	public override void ShowEditor()
	{
		ImGui.PropertyTableStartNewProperty("Is sRGB");
		ImGui.AttachTooltip("If checked, the texture will be forced to be imported as sRGB. Refer to the documentation for an detailed explanation what you should do here.");

		bool isSrgb = _isSrgb;
		if (ImGui.Checkbox("##isSrgb", &isSrgb))
		{
			IsSrgb = isSrgb;
		}
	}
}


class TextureImporter : IAssetImporter
{
	private static readonly List<StringView> _fileExtensions = new .(){".png", ".dds"} ~ delete _;

	public static List<StringView> FileExtensions => _fileExtensions;

	public AssetImporterConfig CreateDefaultConfig()
	{
		return new TextureImporterConfig();
	}

	public Result<ImportedResource> Import(StringView fullFileName, AssetIdentifier assetIdentifier, AssetImporterConfig config)
	{

		Log.EngineLogger.AssertDebug(config is TextureImporterConfig);

		ImportedTexture importedData = new ImportedTexture(new AssetIdentifier(assetIdentifier.FullIdentifier));

		// TODO: Get stream from asset mananger?
		FileStream stream = scope FileStream();
		Try!(stream.Open(fullFileName, .Read, .Read));

		Result<void> importResult = ImportTexture(stream, importedData, (TextureImporterConfig)config);

		stream.Close();

		if (importResult case .Err)
		{
			delete importedData;
			return .Err;
		}

		return importedData;
	}

	const String PngMagicWord = "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A";
	const String DdsMagicWord = "DDS ";

	enum TextureType
	{
		Unknown,
		DDS,
		PNG
	}

	private static TextureType GetTextureType(Stream data)
	{
		int64 position = data.Position;
		
		var readResult = data.Read<char8[8]>();

		data.Position = position;
		
		char8[8] magicWord;
		if (readResult case .Ok(out magicWord))
		{
			StringView strView = .(&magicWord, magicWord.Count);

			if (strView.StartsWith(PngMagicWord))
			{
				return .PNG;
			}
			else if (strView.StartsWith(DdsMagicWord))
			{
				return .DDS;
			}
			else
			{
				Runtime.FatalError("Unknown image format.");
			}
		}

		return .Unknown;
	}

	private static Result<void> ImportTexture(Stream data, ImportedTexture importedTexture, TextureImporterConfig config)
	{
		Debug.Profiler.ProfileResourceFunction!();

		switch(GetTextureType(data))
		{
		case .DDS:
			Try!(LoadDds(data, config, importedTexture.Surfaces, out importedTexture.TextureInfo));
		case .PNG:
			Try!(LoadPng(data, config, importedTexture.Surfaces, out importedTexture.TextureInfo));
		case .Unknown:
			Log.EngineLogger.Error("Unknown texture format.");
			return .Err;
		}
		
		return .Ok;
	}

	private static Result<void> LoadPng(Stream data, TextureImporterConfig config, List<LoadedSurface> surfaces, out LoadedTextureInfo textureInfo)
	{
		Debug.Profiler.ProfileResourceFunction!();
		
		textureInfo = .();

		uint8[] pngData = new:ScopedAlloc! uint8[data.Length];

		var result = data.TryRead(pngData);

		if (result case .Err(let err))
		{
			Log.EngineLogger.Error($"Failed to read data from stream. Texture: Error: {err}");
			return .Err;
		}

		uint8* rawData = null;
		defer
		{
			if (rawData != null)
				LodePng.LodePng.Free(rawData);
		}

		uint32 width = 0, height = 0;

		{
			Debug.Profiler.ProfileResourceScope!("LodePng.LodePng.Decode32");
			uint32 errorCode = LodePng.LodePng.Decode32(&rawData, &width, &height, pngData.Ptr, (.)pngData.Count);
			if (errorCode != 0)
			{
				Log.EngineLogger.Error($"Failed to decode PNG file {errorCode}.");
				return .Err;
			}
		}

		uint8[] pixelData = new uint8[4 * width * height];
		Internal.MemCpy(pixelData.Ptr, rawData, pixelData.Count);

		LoadedSurface surface = .();
		surface.Data = Span<uint8>(pixelData);
		surface.Pitch = 4 * width;
		surface.SlicePitch = 0;
		surface.ArrayIndex = 0;
		surface.MipLevel = 0;
		surface.Width = width;
		surface.Height = height;
		surface.Depth = 1;

		surfaces.Add(surface);

		textureInfo.PixelData = pixelData;
		textureInfo.Width = width;
		textureInfo.Height = height;
		textureInfo.Depth = 1;

		textureInfo.ArraySize = 1;
		textureInfo.MipMapCount = 1;

		textureInfo.Dimension = .Texture2D;

		textureInfo.IsCubeMap = false;

		// TODO: PNG supports multiple colordepths! (Grayscale up to 16 bit, RGB 8 or 16 bit)
		textureInfo.PixelFormat = config.IsSrgb ? .R8G8B8A8_UNorm_SRGB : .R8G8B8A8_UNorm;

		return .Ok;
	}

	private static Result<void> LoadDds(Stream data, TextureImporterConfig config, List<LoadedSurface> surfaces, out LoadedTextureInfo textureInfo)
	{
		var result = DdsImporter.LoadDds(data, config.IsSrgb, surfaces, out textureInfo);

		if (result case .Err)
			return .Err;

		return .Ok;
	}
}
