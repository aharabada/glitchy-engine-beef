using System;
using System.IO;
using System.Collections;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using System.Threading;

namespace GlitchyEngine.Content;

class TextureLoader : IProcessedAssetLoader
{
	public Result<Asset> Load(Stream dataStream)
	{
		TextureDimension dimension = Try!(dataStream.Read<TextureDimension>());
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

		using (SamplerState samplerState = SamplerStateManager.GetSampler(sampler))
		{
			result.SamplerState = samplerState;
		}

		//Thread.Sleep(1000);

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
