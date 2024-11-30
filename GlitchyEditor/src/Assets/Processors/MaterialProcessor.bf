using System;
using System.Collections;
using GlitchyEditor.Assets.Importers;
using GlitchyEngine.Renderer;
using GlitchyEngine;
using GlitchyEngine.Content;

namespace GlitchyEditor.Assets.Processors;

class ProcessedMaterial : ProcessedResource
{
	private Dictionary<String, uint8[]> _bufferData = new .() ~ DeleteDictionaryAndKeysAndValues!(_);
	
	public override AssetType AssetType => .Material;

	public this(AssetIdentifier ownAssetIdentifier, AssetHandle assetHandle) : base(ownAssetIdentifier, assetHandle)
	{

	}

	public uint8[] CloneBuffer(ConstantBuffer cBuffer)
	{
		String name = new String(cBuffer.Name);
		//uint8[] data = cBuffer.

		return null;
	}
}

class MaterialProcessor : IAssetProcessor
{
	public AssetProcessorConfig CreateDefaultConfig()
	{
		return new AssetProcessorConfig();
	}

	public static Type ProcessedAssetType => typeof(NewMaterialFile)

	public Result<void> Process(ImportedResource importedResource, AssetConfig config, List<ProcessedResource> outProcessedResources)
	{
		NewMaterialFile importedMaterial = importedResource as NewMaterialFile;
		if (importedMaterial == null)
		{
			Log.EngineLogger.Error($"Expected type {nameof(NewMaterialFile)} but received {importedResource.GetType()} instead.");
			return .Err;
		}

		Effect effect = Content.GetAsset<Effect>(importedMaterial.Effect, blocking: true);

		ProcessedMaterial processedMaterial = new .(new AssetIdentifier(importedMaterial.AssetIdentifier), config.AssetHandle);

		for (let buffer in effect.Buffers)
		{
			ConstantBuffer cBuffer = buffer.Buffer as ConstantBuffer;

			if (cBuffer == null)
			{

			}

			processedMaterial.CloneBuffer(cBuffer);
		}

		// Create buffers

		return default;
	}
}