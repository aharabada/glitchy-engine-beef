using System;
using System.Collections;
using System.IO;
using GlitchyEngine.Content;
using GlitchyEditor.Assets.Processors;

namespace GlitchyEditor.Assets.Importers;

interface IAssetImporter
{
	static List<StringView> FileExtensions {get;}

	AssetImporterConfig CreateDefaultConfig();

	/// The type that ImportedResource returns.
	static Type ProcessedAssetType { get; }

	Result<ImportedResource> Import(StringView fullFileName, AssetIdentifier assetIdentifier, AssetImporterConfig config);
}

interface IAssetProcessor
{
	AssetProcessorConfig CreateDefaultConfig();
	
	/// The asset type that this processor can process.
	static Type ProcessedAssetType { get; }

	Result<void> Process(ImportedResource importedResource, AssetProcessorConfig config, List<ProcessedResource> outProcessedResources);
}

interface IAssetExporter
{
	AssetExporterConfig CreateDefaultConfig();

	/// The asset type that this exporter can export.
	static AssetType ExportedAssetType { get; }

	Result<void> Export(Stream stream, ProcessedResource processedObject, AssetExporterConfig config);
}
