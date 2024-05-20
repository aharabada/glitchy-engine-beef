using System;
using System.Collections;
using System.IO;
using Bon;
using GlitchyEngine.Content;
using GlitchyEngine;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using static GlitchyEditor.Assets.Importers.LoadedTextureInfo;

namespace GlitchyEditor.Assets.Importers;

class ImportedResource
{
	private AssetIdentifier _assetIdentifier ~ delete _;

	public AssetIdentifier AssetIdentifier => _assetIdentifier;

	public this(AssetIdentifier ownAssetIdentifier)
	{
		_assetIdentifier = ownAssetIdentifier;
	}
}

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

enum GenerateMipMaps
{
	No,
	Box,
	Kaiser
}

[BonTarget, BonPolyRegister]
class TextureProcessorConfig : AssetProcessorConfig
{
	[BonInclude]
	private GenerateMipMaps _generateMipMaps;
	
	[BonInclude]
	private SamplerStateDescription _samplerStateDescription = .();

	public GenerateMipMaps GenerateMipMaps
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

abstract class ProcessedResource
{
	private AssetIdentifier _assetIdentifier ~ delete _;

	public AssetIdentifier AssetIdentifier => _assetIdentifier;

	public abstract AssetType AssetType {get;}

	public this(AssetIdentifier ownAssetIdentifier)
	{
		_assetIdentifier = ownAssetIdentifier;
	}
}

class ProcessedTexture : ProcessedResource
{
	public Format PixelFormat = .Unknown;
	public int MipMapCount = -1;
	public int ArraySize = -1;
	public Dimension Dimension = .Unknown;
	public bool IsCubeMap;

	public int Width = -1;
	public int Height = -1;
	public int Depth = -1;

	public SamplerStateDescription SamplerStateDescription;

	public override AssetType AssetType => .Texture;

	public class TextureSurface
	{
		public uint8[] PixelData;
		public int Width;
		public int Height;
		public int Depth;
		public int MipLevel;
		public int ArraySlice;
		public int LinePitch;
		public int SlicePitch;

		[AllowAppend]
		public this(int width, int height, int depth, Span<uint8> data, int mipLevel, int arraySlice, int linePitch, int slicePitch)
		{
			uint8[] pixelData = append uint8[data.Length];
			data.CopyTo(pixelData);

			PixelData = pixelData;
			Width = width;
			Height = height;
			Depth = depth;
			MipLevel = mipLevel;
			ArraySlice = arraySlice;
			LinePitch = linePitch;
			SlicePitch = slicePitch;
		}

		public uint64 LoadRaw(int x, int y, int z, Format format, ComponentInfo component)
		{
			Log.EngineLogger.AssertDebug(x >= 0 && y >= 0 && z >= 0 && x < Width && y < Height && z < Depth);

			int64 pixelOffset = x + (Width * y) + (Width * Height) * z;

			int64 bitOffset = pixelOffset * format.BitsPerPixel();

			bitOffset += component.BitSize;

			int64 byteOffset = bitOffset / 8;
			int shift = bitOffset % 8;

			int bytesToRead = (component.BitSize + shift) / 8;

			Log.EngineLogger.AssertDebug(bytesToRead <= 8);

			uint64 data = 0;

			data = PixelData.Ptr[byteOffset];
			data >>= shift;
			uint64 mask = (1 << component.BitSize) - 1;
			data &= mask;

			return data;
		}
	}

	public TextureSurface[,] Surfaces;

	public this(AssetIdentifier ownAssetIdentifier) : base(ownAssetIdentifier)
	{

	}

	public ~this()
	{
		for (int i < Surfaces?.GetLength(0) ?? 0)
		{
			for (int j < Surfaces.GetLength(1))
			{
				delete Surfaces[i, j];
			}
		}

		delete Surfaces;
	}

	public void SetSurfaceCount(int arraySize, int mipMapCount)
	{
		Log.EngineLogger.AssertDebug(Surfaces == null || arraySize > Surfaces.GetLength(0));
		Log.EngineLogger.AssertDebug(Surfaces == null ||mipMapCount > Surfaces.GetLength(1));

		ArraySize = arraySize;
		MipMapCount = mipMapCount;

		TextureSurface[,] oldSurfaces = Surfaces;
		Surfaces = new TextureSurface[arraySize, mipMapCount];

		if (oldSurfaces != null)
		{
			for (int i < oldSurfaces.GetLength(0))
			{
				for (int j < oldSurfaces.GetLength(1))
				{
					Surfaces[i, j] = oldSurfaces[i, j];
				}
			}
		}
	}
}

class TextureProcessor : IAssetProcessor
{
	public AssetProcessorConfig CreateDefaultConfig()
	{
		return new TextureProcessorConfig();
	}

	public Result<ProcessedResource> Process(ImportedResource importedObject, AssetProcessorConfig config)
	{
		Log.EngineLogger.AssertDebug(config is TextureProcessorConfig);
		Log.EngineLogger.AssertDebug(importedObject is ImportedTexture);

		return Try!(ProcessTexture(importedObject as ImportedTexture, config as TextureProcessorConfig));
	}

	private Result<ProcessedTexture> ProcessTexture(ImportedTexture importedTexture, TextureProcessorConfig config)
	{
		ProcessedTexture processedTexture = new ProcessedTexture(new AssetIdentifier(importedTexture.AssetIdentifier.FullIdentifier));

		processedTexture.Dimension = importedTexture.TextureInfo.Dimension;
		processedTexture.PixelFormat = (.)importedTexture.TextureInfo.PixelFormat;
		processedTexture.IsCubeMap = importedTexture.TextureInfo.IsCubeMap;
		processedTexture.Width = importedTexture.TextureInfo.Width;
		processedTexture.Height = importedTexture.TextureInfo.Height;
		processedTexture.Depth = importedTexture.TextureInfo.Depth;
		
		processedTexture.SamplerStateDescription = config.SamplerStateDescription;

		processedTexture.SetSurfaceCount(importedTexture.TextureInfo.ArraySize, importedTexture.TextureInfo.MipMapCount);

		for (LoadedSurface loadedSurface in importedTexture.Surfaces)
		{
			ProcessedTexture.TextureSurface surface = new .(loadedSurface.Width, loadedSurface.Height, loadedSurface.Depth,
				loadedSurface.Data, loadedSurface.MipLevel, loadedSurface.ArrayIndex, loadedSurface.Pitch, loadedSurface.SlicePitch);
			processedTexture.Surfaces[loadedSurface.ArrayIndex, loadedSurface.MipLevel] = surface;
		}

		if (!(config.GenerateMipMaps case .No))
		{
			// TODO: Unpack BC-Formats to RGBA

			GenerateMipMaps(processedTexture, config);
		}

		// TODO: Pack to BC-Format or what ever was selected.

		return processedTexture;
	}

	private int CalculateMipMapCount(int width, int height, int depth)
	{
		var width, height, depth;

		int count = 0;

		while (true)
		{
			count++;

			if (width == 1 && height == 1 && depth == 1)
				break;

			if (width > 1)
				width >>= 1;
			if (height > 1)
				height >>= 1;
			if (depth > 1)
				depth >>= 1;
		}

		return count;
	}

	public bool CanGenerateMipMaps(Format format)
	{
		// TODO!
		return true;
	}

	private Result<void> GenerateMipMaps(ProcessedTexture processedTexture, TextureProcessorConfig config)
	{
		if (!CanGenerateMipMaps(processedTexture.PixelFormat))
		{
			return .Err;
		}

		int mipMapCount = CalculateMipMapCount(processedTexture.Width, processedTexture.Height, processedTexture.Depth);

		if (processedTexture.MipMapCount != mipMapCount)
		{
			processedTexture.SetSurfaceCount(processedTexture.ArraySize, mipMapCount);
		}

		for (int arraySlice < processedTexture.ArraySize)
		{
			ProcessedTexture.TextureSurface largerSurface = processedTexture.Surfaces[arraySlice, 0];

			for (int mipMap = 1; mipMap < processedTexture.MipMapCount; mipMap++)
			{
				ref ProcessedTexture.TextureSurface surface = ref processedTexture.Surfaces[arraySlice, mipMap];

				surface = GenerateMipLevel(processedTexture.PixelFormat, largerSurface, surface);

				largerSurface = surface;
			}
		}

		return .Ok;

		// TODO: Generate Mip Maps
		/*int mipMapCount = CalculateMipMapCount(processedTexture.Width, processedTexture.Height, processedTexture.Depth);

		processedTexture.SetMipMapCount(mipMapCount);

		for (int slice < processedTexture.ArraySize)
		{
			for (int mipMap < mipMapCount)
			{
				if (processedTexture.Surfaces[slice, mipMap] == null)
				{
					processedTexture.Surfaces[slice, mipMap] = GenerateMipLevel(processedTexture.Surfaces[slice, mipMap - 1]);
				}
			}
		}
		*/
	}

	private ProcessedTexture.TextureSurface GenerateMipLevel(Format pixelFormat, ProcessedTexture.TextureSurface largerLevel, ProcessedTexture.TextureSurface smallerLevel)
	{
		var smallerLevel;

		int width = Math.Max(largerLevel.Width / 2, 1);
		int height = Math.Max(largerLevel.Height / 2, 1);
		int depth = Math.Max(largerLevel.Depth / 2, 1);

		if (smallerLevel == null)
		{
			smallerLevel = new ProcessedTexture.TextureSurface(width, height, depth,
				new uint8[width * height * depth * pixelFormat.BitsPerPixel()], largerLevel.MipLevel + 1, largerLevel.ArraySlice,
				-1, -1); // TODO!
		}

		// TODO: Kaiser mip maps?

		FormatInfo formatInfo = default; //pixelFormat.GetFormatInfo();

		// Simple box filter
		for (int x < width)
		for (int y < height)
		for (int z < depth)
		{
			for (int channel < formatInfo.ComponentCount)
			{
				ComponentInfo info = formatInfo.Components[channel];

				switch (info.DataType)
				{
				case .UNorm, .UInt:
					
				default:
				}
			}
		}

		return smallerLevel;
	}

	private void Box<DataType>() where DataType : const ComponentDataType
	{

	}
}

class TextureExporter : IAssetExporter
{
	public AssetExporterConfig CreateDefaultConfig()
	{
		return new AssetExporterConfig();
	}

	public Result<void> Export(Stream stream, ProcessedResource processedResource, AssetExporterConfig config)
	{
		Log.EngineLogger.AssertDebug(processedResource is ProcessedTexture);

		ProcessedTexture processedTexture = (.)processedResource;

		/*

		File Format:
		TextureType (1 byte)
		Pixel Format (4 bytes)
		Width of larges mip-slice (4 bytes)
		Height of larges mip-slice (4 bytes)
		Depth of larges mip-slice (4 bytes)
		Array size (4 bytes)
		Mip map levels (4 bytes)
		Is Cubemap (1 byte)
		Data Byte count (8 bytes)
		Pixeldata
		{
			Array[0]: Mip[0] Mip[1] ... Mip[M]
			Array[1]: Mip[0] Mip[1] ... Mip[M]
			...
			Array[N]: Mip[0] Mip[1] ... Mip[M]
		}

		*/

		Try!(stream.Write(processedTexture.Dimension));
		Try!(stream.Write(processedTexture.PixelFormat));
		Try!(stream.Write((uint32)processedTexture.Width));
		Try!(stream.Write((uint32)processedTexture.Height));
		Try!(stream.Write((uint32)processedTexture.Depth));
		Try!(stream.Write((uint32)processedTexture.ArraySize));
		Try!(stream.Write((uint32)processedTexture.MipMapCount));
		Try!(stream.Write(processedTexture.IsCubeMap));

		Try!(WriteSamplerStateDescription(stream, processedTexture.SamplerStateDescription));

		for (int arraySlice < processedTexture.ArraySize)
		{
			int validateWidth = processedTexture.Width;
			int validateHeight = processedTexture.Height;
			int validateDepth = processedTexture.Depth;

			for (int mipSlice < processedTexture.MipMapCount)
			{
				ProcessedTexture.TextureSurface slice = processedTexture.Surfaces[arraySlice, mipSlice];

				Log.EngineLogger.AssertDebug(validateWidth == slice.Width);
				Log.EngineLogger.AssertDebug(validateHeight == slice.Height);
				Log.EngineLogger.AssertDebug(validateDepth == slice.Depth);
				validateWidth /= 2;
				validateHeight /= 2;
				validateDepth /= 2;

				if (validateWidth < 1)
					validateWidth = 1;

				if (validateHeight < 1)
					validateHeight = 1;

				if (validateDepth < 1)
					validateDepth = 1;
				
				Try!(stream.Write((uint32)slice.LinePitch));
				Try!(stream.Write((uint32)slice.SlicePitch));
				Try!(stream.Write((uint64)slice.PixelData.Count));
				Try!(stream.TryWrite(slice.PixelData));
			}
		}

		return .Ok;
	}

	private Result<void> WriteSamplerStateDescription(Stream stream, SamplerStateDescription sampler)
	{
		Try!(stream.Write(sampler.MinFilter));
		Try!(stream.Write(sampler.MagFilter));
		Try!(stream.Write(sampler.MipFilter));
		Try!(stream.Write(sampler.FilterMode));
		Try!(stream.Write(sampler.ComparisonFunction));
		Try!(stream.Write(sampler.AddressModeU));
		Try!(stream.Write(sampler.AddressModeV));
		Try!(stream.Write(sampler.AddressModeW));
		Try!(stream.Write(sampler.MipLODBias));
		Try!(stream.Write(sampler.MipMinLOD));
		Try!(stream.Write(sampler.MipMaxLOD));
		Try!(stream.Write(sampler.MaxAnisotropy));
		Try!(stream.Write(sampler.BorderColor));

		return .Ok;
	}
}

class TextureLoader : IProcessedAssetLoader
{
	public Result<Asset> Load(Stream dataStream)
	{
		Dimension dimension = Try!(dataStream.Read<Dimension>());
		Format pixelFormat = Try!(dataStream.Read<Format>());
		uint32 width = Try!(dataStream.Read<uint32>());
		uint32 height = Try!(dataStream.Read<uint32>());
		uint32 depth = Try!(dataStream.Read<uint32>());
		uint32 arraySize = Try!(dataStream.Read<uint32>());
		uint32 mipMapCount = Try!(dataStream.Read<uint32>());
		bool isCubemap = Try!(dataStream.Read<bool>());

		SamplerStateDescription sampler = Try!(ReadSampler(dataStream));
		
		List<uint8[]> surfaceDatas = scope .(mipMapCount * arraySize);
		defer { ClearAndDeleteItems!(surfaceDatas); }

		TextureSliceData[] slices = scope TextureSliceData[mipMapCount * arraySize];

		int index = 0;
		for (int arraySlice < arraySize)
		{
			for (int mipSlice < mipMapCount)
			{
				uint32 linePitch = Try!(dataStream.Read<uint32>());
				uint32 slicePitch = Try!(dataStream.Read<uint32>());
				uint64 byteCount = Try!(dataStream.Read<uint64>());

				uint8[] surfaceData = new uint8[byteCount];
				Try!(dataStream.TryRead(surfaceData));
				slices[index] = .(surfaceData.Ptr, linePitch, slicePitch);

				index++;

				surfaceDatas.Add(surfaceData);
			}
		}

		Texture result = null;

		switch (dimension)
		{
		case .Texture2D:
			if (isCubemap)
			{
				Runtime.NotImplemented();
			}
			else
			{
				Texture2DDesc desc = .(width, height, pixelFormat, arraySize, mipMapCount, .Immutable, .None);

				Texture2D texture = new Texture2D(desc);

				texture.SetData(slices);

				result = texture;
			}
		default:
			Runtime.NotImplemented();
		}

		result.SamplerState = SamplerStateManager.GetSampler(sampler);

		return result;
	}

	private Result<SamplerStateDescription> ReadSampler(Stream dataStream)
	{
		SamplerStateDescription sampler;

		sampler.MinFilter = Try!(dataStream.Read<FilterFunction>());
		sampler.MagFilter = Try!(dataStream.Read<FilterFunction>());
		sampler.MipFilter = Try!(dataStream.Read<FilterFunction>());
		sampler.FilterMode = Try!(dataStream.Read<FilterMode>());
		sampler.ComparisonFunction = Try!(dataStream.Read<ComparisonFunction>());
		sampler.AddressModeU = Try!(dataStream.Read<TextureAddressMode>());
		sampler.AddressModeV = Try!(dataStream.Read<TextureAddressMode>());
		sampler.AddressModeW = Try!(dataStream.Read<TextureAddressMode>());
		sampler.MipLODBias = Try!(dataStream.Read<float>());
		sampler.MipMinLOD = Try!(dataStream.Read<float>());
		sampler.MipMaxLOD = Try!(dataStream.Read<float>());
		sampler.MaxAnisotropy = Try!(dataStream.Read<uint8>());
		sampler.BorderColor = Try!(dataStream.Read<ColorRGBA>());

		return sampler;
	}
}
