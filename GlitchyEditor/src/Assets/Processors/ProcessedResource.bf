using GlitchyEngine.Content;

namespace GlitchyEditor.Assets.Processors;

abstract class ProcessedResource
{
	private AssetIdentifier _assetIdentifier ~ delete _;

	public AssetIdentifier AssetIdentifier => _assetIdentifier;

	public abstract AssetType AssetType {get;}

	public this(AssetIdentifier ownAssetIdentifier)
	{
		_assetIdentifier = ownAssetIdentifier;
	}
}