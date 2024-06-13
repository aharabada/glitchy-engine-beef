using GlitchyEngine.Content;
using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer;

class Sprite : Asset
{
	private AssetHandle _textureHandle;
	private float4 _textureCoordinates;

	public AssetHandle TextureHandle => _textureHandle;

	public float4 TextureCoordinates => _textureCoordinates;

	public this(AssetHandle textureHandle, float4 textureCoordinates)
	{
		_textureHandle = textureHandle;
		_textureCoordinates = textureCoordinates;
	}
}