using System;
using System.Collections;
using System.IO;
using GlitchyEngine.Renderer;

namespace GlitchyEngine.Content.Loaders;

class MaterialLoader : IProcessedAssetLoader
{
	public Result<Asset> Load(Stream stream)
	{
		Compiler.Assert(sizeof(AssetHandle) == 8);

		AssetHandle<Effect> effectHandle = Try!(stream.Read<AssetHandle>());
		
		Effect effect = Content.GetAsset<Effect>(effectHandle, blocking: true);

		Material material = new Material(effect);

		uint16 textureCount = Try!(stream.Read<uint16>());

		for (int i < textureCount)
		{
			AssetHandle<Texture> textureHandle = Try!(stream.Read<AssetHandle>());

			int16 textureNameLength = Try!(stream.Read<int16>());
			String textureName = scope String(textureNameLength);
			stream.ReadStrSized32(textureNameLength, textureName);

			material.SetTexture(textureName, textureHandle);
		}

		uint16 bufferCount = Try!(stream.Read<uint16>());

		for (int i < bufferCount)
		{
			int64 bufferDataSize = Try!(stream.Read<int64>());
			int16 textureNameLength = Try!(stream.Read<int16>());
			String textureName = scope String(textureNameLength);
			stream.ReadStrSized32(textureNameLength, textureName);

			uint8[] data = new:ScopedAlloc! uint8[bufferDataSize];

			Try!(stream.TryRead(data));

			// TODO: Somehow get buffer data into material
		}

		material.SetVariable("AlbedoColor", GlitchyEngine.Math.float4(1.0f, 0, 0, 1.0f));

		return material;
	}
}
