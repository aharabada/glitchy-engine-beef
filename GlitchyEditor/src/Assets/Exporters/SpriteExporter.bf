using System;
using System.IO;
using GlitchyEngine.Renderer;
using GlitchyEditor.Assets.Processors;
using GlitchyEngine;
using GlitchyEditor.Assets.Importers;
using GlitchyEngine.Content;

namespace GlitchyEditor.Assets.Exporters;

class SpriteExporter : IAssetExporter
{
	public static AssetType ExportedAssetType => .Sprite;

	public AssetExporterConfig CreateDefaultConfig()
	{
		return new AssetExporterConfig();
	}

	public Result<void> Export(Stream stream, ProcessedResource processedResource, AssetConfig config)
	{
		Log.EngineLogger.AssertDebug(processedResource is ProcessedSprite);

		ProcessedSprite processedSprite = (.)processedResource;

		/*

		File Format:
		TextureHandle (8 bytes)
		TextureCoords (16 bytes) [float4]
		
		*/

		Try!(stream.Write(processedSprite.TextureHandle));
		Try!(stream.Write(processedSprite.TextureCoordinates));

		return .Ok;
	}
}
