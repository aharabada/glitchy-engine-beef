using GlitchyEngine.Renderer;
namespace GlitchyEditor.Assets;

class AssetThumbnailManager
{
	private EditorIcons _icons ~ _.ReleaseRef();

	public this(EditorIcons icons)
	{
		_icons = icons..AddRef();
	}

	public SubTexture2D GetThumbnail(AssetNode assetNode)
	{
		if (assetNode.IsDirectory)
			return _icons.Folder;
		
		if (assetNode.Path.EndsWith(".scene"))
			return _icons.File_Scene;

		if (assetNode.Path.EndsWith(".mat"))
			return _icons.File_Material;

		if (assetNode.Path.EndsWith(".cs"))
			return _icons.File_CSharpScript;
		
		if (assetNode.Path.EndsWith(".hlsl"))
			return _icons.File_Shader;

		return _icons.File;
	}
}
