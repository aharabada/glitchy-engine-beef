using System;
using System.Collections;
using GlitchyEngine.Renderer;
using GlitchyEngine.Content;
namespace GlitchyEditor.Assets;

// TODO: Why exactly are AssetFile and AssetNode separated?
public class AssetNode
{
	public String Name ~ delete _;
	public String Path ~ delete _;
	public AssetIdentifier Identifier ~ delete _;

	public bool IsDirectory;

	public AssetFile AssetFile ~ delete _;

	public List<SubAsset> SubAssets ~ {
		SubAssets?.ClearAndDeleteItems();
		delete SubAssets;
	}

	public Texture2D PreviewImage ~ _?.ReleaseRef();
}

public class SubAsset
{
	public AssetNode Asset;
	public String Name ~ delete _;
	public AssetIdentifier Identifier ~ delete _;

	public Texture2D PreviewImage ~ _?.ReleaseRef();
}
