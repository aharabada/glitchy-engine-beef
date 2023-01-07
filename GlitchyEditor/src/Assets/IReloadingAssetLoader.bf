using System.IO;

namespace GlitchyEditor.Assets;

interface IReloadingAssetLoader
{
	public void ReloadAsset(AssetFile assetFile, Stream data);
}