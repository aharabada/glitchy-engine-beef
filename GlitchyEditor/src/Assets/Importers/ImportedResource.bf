using GlitchyEngine.Content;

namespace GlitchyEditor.Assets.Importers;

class ImportedResource
{
	private AssetIdentifier _assetIdentifier ~ delete _;

	public AssetIdentifier AssetIdentifier => _assetIdentifier;

	public this(AssetIdentifier ownAssetIdentifier)
	{
		_assetIdentifier = ownAssetIdentifier;
	}
}
