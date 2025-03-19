using System;
using System.Collections;
using GlitchyEditor.Assets.Importers;
using GlitchyEngine.Renderer;
using GlitchyEngine;
using GlitchyEngine.Content;
using System.Diagnostics;

namespace GlitchyEditor.Assets.Processors;

class ProcessedMaterial : ProcessedResource
{
	public AssetHandle EffectHandle;

	private Dictionary<String, uint8[]> _bufferData = new .() ~ DeleteDictionaryAndKeysAndValues!(_);
	private Dictionary<String, AssetHandle> _textures = new .() ~ DeleteDictionaryAndKeys!(_);
	
	public override AssetType AssetType => .Material;

	public Dictionary<String, uint8[]> Buffers => _bufferData;
	public Dictionary<String, AssetHandle> Textures => _textures;

	public this(AssetIdentifier ownAssetIdentifier, AssetHandle assetHandle) : base(ownAssetIdentifier, assetHandle)
	{

	}

	public Span<uint8> CloneBuffer(String name, ConstantBuffer cBuffer)
	{
		String copyName = new String(name);
		uint8[] data = new uint8[cBuffer.RawData.Length];
		cBuffer.RawData.CopyTo(data);

		_bufferData.Add(copyName, data);

		return data;
	}

	public void AddTexture(StringView name, AssetHandle textureHandle)
	{
		String copyName = new String(name);
		_textures.Add(copyName, textureHandle);
	}
}

class MaterialProcessor : IAssetProcessor
{
	public AssetProcessorConfig CreateDefaultConfig()
	{
		return new AssetProcessorConfig();
	}

	public static Type ProcessedAssetType => typeof(NewMaterialFile);

	public Result<void> Process(ImportedResource importedResource, AssetConfig config, List<ProcessedResource> outProcessedResources)
	{
		NewMaterialFile importedMaterial = importedResource as NewMaterialFile;
		if (importedMaterial == null)
		{
			Log.EngineLogger.Error($"Expected type {nameof(NewMaterialFile)} but received {importedResource.GetType()} instead.");
			return .Err;
		}

		Effect effect = Content.GetAsset<Effect>(importedMaterial.Effect, blocking: true);

		if (effect == null)
			// TODO: Don't error out, use the error-effect
			return .Err;

		ProcessedMaterial processedMaterial = new .(new AssetIdentifier(importedMaterial.AssetIdentifier), config.AssetHandle);

		processedMaterial.EffectHandle = importedMaterial.Effect;

		for (let buffer in effect.Buffers)
		{
			// TODO: Skip engine buffers

			if (buffer.Buffer == null)
				continue;

			ConstantBuffer cBuffer = buffer.Buffer as ConstantBuffer;

			if (cBuffer == null)
			{
				Log.EngineLogger.Error("The buffers of a material must be ConstantBuffers.");
				continue;
				// TODO: Why even allow any other kind of Buffer for Materials? Will this make sense later if we can create and bind Buffers from C#?
			}

			Span<uint8> data = processedMaterial.CloneBuffer(buffer.Name, cBuffer);

			for (BufferVariable effectVariable in cBuffer.Variables)
			{
				if (importedMaterial.Constants.TryGetValue(effectVariable.Name, let materialValue))
				{
					if (effectVariable.ElementType != materialValue.ElementType)
					{
						Log.EngineLogger.Error("Element type doesn't match between material and effect.");
						continue;
					}

					int effectVariableSize = effectVariable.Rows * effectVariable.Columns * Math.Max(1, effectVariable.ArrayElements) * effectVariable.ElementType.ElementSizeInBytes();

					if (effectVariableSize != materialValue.RawData.Count)
					{
						Log.EngineLogger.Warning("Warning, matrix size in matrix and effect doesn't match. Truncating value.");
					}
					
					int bytesToCopy = Math.Min(effectVariableSize, materialValue.RawData.Count);
					Debug.Assert(effectVariable.Offset + bytesToCopy <= data.Length, "Material value goes out of bounds ");

					Internal.MemCpy(data.Ptr + effectVariable.Offset, materialValue.RawData.Ptr, bytesToCopy);
				}
			}
		}

		for (let (textureName, textureBinding) in effect.Textures)
		{
			if (importedMaterial.Textures.TryGetValue(textureName, let textureHandle))
			{
				processedMaterial.AddTexture(textureName, textureHandle);
			}
		}

		outProcessedResources.Add(processedMaterial);

		return .Ok;
	}
}