using GlitchyEngine.Content;

namespace GlitchyEditor.Assets.Processors;

abstract class ProcessedResource
{
	private AssetIdentifier _assetIdentifier ~ delete _;

	private AssetHandle _assetHandle;

	public AssetIdentifier AssetIdentifier => _assetIdentifier;

	public AssetHandle AssetHandle => _assetHandle;

	public abstract AssetType AssetType {get;}

	public this(AssetIdentifier ownAssetIdentifier, AssetHandle assetHandle)
	{
		_assetIdentifier = ownAssetIdentifier;
		_assetHandle = assetHandle;
	}
}