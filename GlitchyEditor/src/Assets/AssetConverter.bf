using System.Collections;
using GlitchyEditor.Assets.Importers;
using GlitchyEngine;
using System;
using System.IO;
using GlitchyEngine.Content;
using GlitchyEditor.Assets.Processors;
using System.Threading;
using System.Threading.Tasks;

namespace GlitchyEditor.Assets;

class AssetConverter
{
	private append Queue<AssetFile> _queue = .();

	private EditorContentManager _contentManager;

	private Dictionary<AssetFile, Task> _processingAssets ~ delete _;

	public this(EditorContentManager contentManager)
	{
		_contentManager = contentManager;
	}

	public void QueueForProcessing(AssetFile assetFile, bool isBlocking = false)
	{
		if (isBlocking)
			Process(assetFile);
		else
			_queue.Add(assetFile);
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

		Result<ImportedResource> importResult = importer.Import(assetFile.AssetFile.Path,
			assetFile.AssetFile.Identifier, assetFile.AssetConfig.ImporterConfig);

		if (importResult case .Err)
		{
			Log.EngineLogger.Error("Failed to import asset!");
			return;
		}

		defer { delete importResult.Value; }

		List<ProcessedResource> resources = scope .();
		defer { ClearAndDeleteItems!(resources); }

		Result<void> processResult = processor.Process(importResult.Value, assetFile.AssetConfig.ProcessorConfig, resources);
		
		if (processResult case .Err)
		{
			Log.EngineLogger.Error("Failed to process asset!");
			return;
		}

		for (ProcessedResource resource in resources)
		{
			TrySilent!(ExportResource(assetFile, resource));
		}
	}

	private Result<void> ExportResource(AssetFile assetFile, ProcessedResource resource)
	{
		IAssetExporter exporter = _contentManager.GetAssetExporter(resource.AssetType);

		if (exporter == null)
		{
			Log.EngineLogger.Error($"No exporter for asset type {resource.AssetType}!");
			return .Err;
		}

		MemoryStream memoryStream = scope .();

		Result<void> exportResult = exporter.Export(memoryStream, resource, assetFile.AssetConfig.ExporterConfig);

		if (exportResult case .Err)
		{
			Log.EngineLogger.Error("Failed to export asset!");
			return .Err;
		}

		CachedAsset assetInfo = scope CachedAsset();
		assetInfo.Handle = assetFile.AssetConfig.AssetHandle;
		assetInfo.CreationTimestamp = DateTime.UtcNow;
		assetInfo.Compression = assetFile.AssetConfig.ExporterConfig.Compression;
		assetInfo.AssetIdentifier = new AssetIdentifier(assetFile.AssetFile.Identifier);
		assetInfo.AssetType = resource.AssetType;

		if (_contentManager.AssetCache.SaveAsset(assetInfo, memoryStream.Memory) case .Err)
		{
			Log.EngineLogger.Error("Failed to write asset to cache.");
			return .Err;
		}

		return .Ok;
	}
}