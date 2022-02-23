using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer
{
	class SubTexture2D : RefCounter
	{
		protected Texture2D _texture ~ _.ReleaseRef();
		protected Vector4 _texCoords;

		public Texture2D Texture => _texture;
		public Vector4 TexCoords => _texCoords;
		
		public this(Texture2D texture) : this(_texture, .(0, 0, 1, 1)) {  }

		public this(Texture2D texture, Int2 topLeft, Int2 size) :
			this(texture,
			{
				Vector2 texSize = Vector2(texture.Width, texture.Height);
				Vector4 texCoords = Vector4((Vector2)topLeft, (Vector2)size) / texSize.XYXY;
				texCoords
			}) { }

		public this(Texture2D texture, Vector2 topLeft, Vector2 size) : this(texture, Vector4(topLeft, size)) {  }

		public this(Texture2D texture, Vector4 texCoords)
		{
			_texture = texture..AddRef();
			_texCoords = texCoords;
		}

		public static SubTexture2D CreateFromGrid(Texture2D texture, Vector2 coords, Vector2 gridSize, Vector2 spriteSize = .One)
		{
			Vector2 textureSize = .(texture.Width, texture.Height);

			Vector4 uv = .(coords * gridSize, gridSize * spriteSize) / textureSize.XYXY;

			return new SubTexture2D(texture, uv);
		}
	}
}