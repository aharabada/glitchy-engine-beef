using System.Collections;
using GlitchyEditor.Assets.Importers;
using GlitchyEngine;
using System;
using System.IO;
using GlitchyEngine.Content;

namespace GlitchyEditor.Assets;

class AssetConverter
{
	private append Queue<AssetFile> _queue = .();

	private EditorContentManager _contentManager;

	public this(EditorContentManager contentManager)
	{
		_contentManager = contentManager;
	}

	public void QueueForProcessing(AssetFile assetFile, bool isBlocking = false)
	{
		if (!isBlocking)
			_queue.Add(assetFile);
		else
			Process(assetFile);
	}

	public void Update()
	{
		if (_queue.Count == 0)
			return;

		for (AssetFile assetFile in _queue)
		{
			Process(assetFile);
		}

		_queue.Clear();
	}

	private void Process(AssetFile assetFile)
	{
		IAssetImporter importer = _contentManager.GetAssetImporter(assetFile);
		IAssetProcessor processor = _contentManager.GetAssetProcessor(assetFile);
		IAssetExporter exporter = _contentManager.GetAssetExporter(assetFile);

		if (importer == null)
		{
			Log.EngineLogger.Error("Importer is null!");
			return;
		}
		
		if (processor == null)
		{
			Log.EngineLogger.Error("Processor is null!");
			return;
		}
		
		if (exporter == null)
		{
			Log.EngineLogger.Error("Exporter is null!");
			return;
		}

		Result<ImportedResource> importResult = importer.Import(assetFile.AssetFile.Path,
			assetFile.AssetFile.Identifier, assetFile.AssetConfig.ImporterConfig);

		if (importResult case .Err)
		{
			Log.EngineLogger.Error("Failed to import asset!");
			return;
		}

		defer { delete importResult.Value; }

		Result<ProcessedResource> processResult = processor.Process(importResult.Value, assetFile.AssetConfig.ProcessorConfig);
		
		if (processResult case .Err)
		{
			Log.EngineLogger.Error("Failed to process asset!");
			return;
		}

		defer { delete processResult.Value; }

		MemoryStream memoryStream = scope .();

		Result<void> exportResult = exporter.Export(memoryStream, processResult.Value, assetFile.AssetConfig.ExporterConfig);

		if (exportResult case .Err)
		{
			Log.EngineLogger.Error("Failed to export asset!");
			return;
		}

		CachedAsset assetInfo = scope CachedAsset();
		assetInfo.Handle = assetFile.AssetConfig.AssetHandle;
		assetInfo.CreationTimestamp = DateTime.UtcNow;
		assetInfo.Compression = assetFile.AssetConfig.ExporterConfig.Compression;
		assetInfo.AssetIdentifier = new AssetIdentifier(assetFile.AssetFile.Identifier);
		assetInfo.AssetType = processResult.Value.AssetType;

		if (_contentManager.AssetCache.SaveAsset(assetInfo, memoryStream.Memory) case .Err)
		{
			Log.EngineLogger.Error("Failed to write asset to cache.");
		}
	}
}