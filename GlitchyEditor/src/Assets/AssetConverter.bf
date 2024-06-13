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
		Result<ImportedResource> importResult = ImportResource(assetFile);

		ImportedResource importedResource = null;
		defer { delete importedResource; }

		if (!(importResult case .Ok(out importedResource)))
		{
			Log.EngineLogger.Error("Failed to import asset!");
			return;
		}

		List<ProcessedResource> processedResources = scope .();
		defer { ClearAndDeleteItems!(processedResources); }

		Result<void> processResult = ProcessResource(assetFile, importedResource, processedResources);
		
		if (processResult case .Err)
		{
			Log.EngineLogger.Error("Failed to process asset!");
			return;
		}

		for (ProcessedResource resource in processedResources)
		{
			if (ExportResource(assetFile, resource) case .Err)
			{
				Log.EngineLogger.Error("Failed to export asset.");
			}
		}
	}

	private Result<ImportedResource> ImportResource(AssetFile assetFile)
	{
		IAssetImporter importer = _contentManager.GetAssetImporter(assetFile);

		if (importer == null)
		{
			Log.EngineLogger.Error("Importer is null!");
			return .Err;
		}

		return importer.Import(assetFile.AssetFile.Path, assetFile.AssetFile.Identifier, assetFile.AssetConfig);
	}

	private Result<void> ProcessResource(AssetFile assetFile, ImportedResource importedResource, List<ProcessedResource> outProcessedResources)
	{
		IAssetProcessor processor = _contentManager.GetAssetProcessor(importedResource.GetType());

		if (processor == null)
		{
			Log.EngineLogger.Error($"No asset processor for type {importedResource.GetType()} found.");
			return .Err;
		}

		return processor.Process(importedResource, assetFile.AssetConfig, outProcessedResources);
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

		Result<void> exportResult = exporter.Export(memoryStream, resource, assetFile.AssetConfig);

		if (exportResult case .Err)
		{
			Log.EngineLogger.Error("Failed to export asset!");
			return .Err;
		}

		if (assetFile.AssetConfig.ExporterConfig == null)
		{
			assetFile.AssetConfig.ExporterConfig = new AssetExporterConfig();
		}

		CachedAsset assetInfo = scope CachedAsset();
		assetInfo.Handle = resource.AssetHandle;
		assetInfo.CreationTimestamp = DateTime.UtcNow;
		assetInfo.Compression = assetFile.AssetConfig.ExporterConfig.Compression;
		assetInfo.AssetIdentifier = new AssetIdentifier(resource.AssetIdentifier);
		assetInfo.AssetType = resource.AssetType;

		if (_contentManager.AssetCache.SaveAsset(assetInfo, memoryStream.Memory) case .Err)
		{
			Log.EngineLogger.Error("Failed to write asset to cache.");
			return .Err;
		}

		assetFile.SaveAssetConfigIfChanged();

		return .Ok;
	}
}