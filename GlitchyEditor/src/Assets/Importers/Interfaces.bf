using System;
using System.Collections;
using System.IO;
using GlitchyEngine.Content;

namespace GlitchyEditor.Assets.Importers;

interface IAssetImporter
{
	static List<StringView> FileExtensions {get;}

	AssetImporterConfig CreateDefaultConfig();

	Result<ImportedResource> Import(StringView fullFileName, AssetIdentifier assetIdentifier, AssetImporterConfig config);
}

interface IAssetProcessor
{
	AssetProcessorConfig CreateDefaultConfig();

	Result<Object> Process(ImportedResource importedResource, AssetProcessorConfig config);
}

interface IAssetExporter
{
	AssetExporterConfig CreateDefaultConfig();

	Result<void> Export(Stream stream, ProcessedResource processedObject, AssetExporterConfig config);
}
