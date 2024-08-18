using Bon;
using System;
using System.Collections;
using GlitchyEngine.Content;
using System.IO;

namespace GlitchyEditor.Assets.Importers;

class ImportedShader : ImportedResource
{
	private String _hlslCode = new .() ~ delete _;

	public StringView HlslCode
	{
		get => _hlslCode;
	}

	public this(AssetIdentifier ownAssetIdentifier) : base(ownAssetIdentifier)
	{
	}
}

[BonTarget, BonPolyRegister]
class ShaderImporterConfig : AssetImporterConfig
{

}

class ShaderImporter : IAssetImporter
{
	private static readonly List<StringView> _fileExtensions = new .(){".hlsl"} ~ delete _;

	public static List<StringView> FileExtensions => _fileExtensions;
	
	public static Type ProcessedAssetType => typeof(ImportedShader);

	public AssetImporterConfig CreateDefaultConfig()
	{
		return new AssetImporterConfig();
	}

	public Result<ImportedResource> Import(StringView fullFileName, AssetIdentifier assetIdentifier, AssetConfig config)
	{
		ImportedShader shader = new ImportedShader(new AssetIdentifier(assetIdentifier));

		Try!(File.ReadAllText(fullFileName, shader.[Friend]_hlslCode, true));
		shader.[Friend]_hlslCode.Append('\n');

		return shader;
	}
}
