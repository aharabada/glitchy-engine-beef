namespace GlitchyEditor.Assets;

abstract class AssetPropertiesEditor
{
	private AssetFile _asset;

	public AssetFile Asset => _asset;

	public this(AssetFile asset)
	{
		_asset = asset;
	}

	public abstract void ShowEditor();
}