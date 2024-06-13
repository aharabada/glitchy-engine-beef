using System;
using System.IO;
using System.Collections;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using System.Threading;

namespace GlitchyEngine.Content;

class SpriteLoader : IProcessedAssetLoader
{
	public Result<Asset> Load(Stream dataStream)
	{
		AssetHandle textureHandle = Try!(dataStream.Read<AssetHandle>());
		float4 textureCoordinates = Try!(dataStream.Read<float4>());

		return new Sprite(textureHandle, textureCoordinates);
	}
}
