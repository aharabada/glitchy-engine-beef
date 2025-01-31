using System;
using System.IO;
using GlitchyEngine.Renderer;
using GlitchyEditor.Assets.Processors;
using GlitchyEngine;
using GlitchyEditor.Assets.Importers;
using GlitchyEngine.Content;
using System.Diagnostics;
namespace GlitchyEditor.Assets.Exporters;


class MaterialExporter : IAssetExporter
{
	public static AssetType ExportedAssetType => .Material;

	public AssetExporterConfig CreateDefaultConfig()
	{
		return new AssetExporterConfig();
	}

	public Result<void> Export(Stream stream, ProcessedResource processedResource, AssetConfig config)
	{
		Log.EngineLogger.AssertDebug(processedResource is ProcessedMaterial);

		ProcessedMaterial processedMaterial = (.)processedResource;

		Compiler.Assert(sizeof(AssetHandle) == 8);

		/*
		File Format:
		Effect Asset Handle (8 byte)
		Texture Count (uint16)
		Textures
		{
			Texture Handle (8 byte)
			Texture Name Length (int16)
			Texture Name Data...
		}
		Buffer Count (uint16)
		Buffers
		{
			Buffer Size (int64)
			Buffer Name Length (int16)
			Buffer Name Data...
			Raw Buffer Data...
		}
		*/
		
		Try!(stream.Write((AssetHandle)processedMaterial.EffectHandle));
		Try!(WriteTextures(stream, processedMaterial));
		Try!(WriteBuffers(stream, processedMaterial));

		return .Ok;
	}

	private Result<void> WriteTextures(Stream stream, ProcessedMaterial processedMaterial)
	{
		Log.EngineLogger.Assert(processedMaterial.Textures.Count < int16.MaxValue);

		Try!(stream.Write((uint16)processedMaterial.Textures.Count));

		for (let (textureName, textureHandle) in processedMaterial.Textures)
		{
			Try!(stream.Write((AssetHandle)textureHandle));

			Log.EngineLogger.Assert(textureName.Length < int16.MaxValue);

			Try!(stream.Write((int16)textureName.Length));
			Try!(stream.Write(textureName));
		}

		return .Ok;
	}
	

	private Result<void> WriteBuffers(Stream stream, ProcessedMaterial processedMaterial)
	{
		Log.EngineLogger.Assert(processedMaterial.Buffers.Count < int16.MaxValue);

		Try!(stream.Write((uint16)processedMaterial.Buffers.Count));

		for (let (bufferName, bufferData) in processedMaterial.Buffers)
		{
			Try!(stream.Write((int64)bufferData.Count));

			Log.EngineLogger.Assert(bufferName.Length < int16.MaxValue);

			Try!(stream.Write((int16)bufferName.Length));
			Try!(stream.Write(bufferName));

			Try!(stream.Write(Span<uint8>(bufferData)));
		}

		return .Ok;
	}
}
