using System;
using System.IO;
using GlitchyEngine.Renderer;
using GlitchyEditor.Assets.Processors;
using GlitchyEngine;
using GlitchyEditor.Assets.Importers;
using GlitchyEngine.Content;
namespace GlitchyEditor.Assets.Exporters;


class TextureExporter : IAssetExporter
{
	public static AssetType ExportedAssetType => .Texture;

	public AssetExporterConfig CreateDefaultConfig()
	{
		return new AssetExporterConfig();
	}

	public Result<void> Export(Stream stream, ProcessedResource processedResource, AssetConfig config)
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
