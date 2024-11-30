using System;

namespace GlitchyEditor.Assets;

[Obsolete]
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