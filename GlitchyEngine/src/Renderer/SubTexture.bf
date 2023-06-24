using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer
{
	class SubTexture2D : RefCounter
	{
		protected Texture2D _texture ~ _.ReleaseRef();
		protected float4 _texCoords;

		public Texture2D Texture => _texture;
		public float4 TexCoords => _texCoords;
		
		public this(Texture2D texture) : this(_texture, .(0, 0, 1, 1)) {  }

		public this(Texture2D texture, Int2 topLeft, Int2 size) :
			this(texture,
			{
				float2 texSize = float2(texture.Width, texture.Height);
				float4 texCoords = float4((float2)topLeft, (float2)size) / texSize.XYXY;
				texCoords
			}) { }

		public this(Texture2D texture, float2 topLeft, float2 size) : this(texture, float4(topLeft, size)) {  }

		public this(Texture2D texture, float4 texCoords)
		{
			_texture = texture..AddRef();
			_texCoords = texCoords;
		}

		public static SubTexture2D CreateFromGrid(Texture2D texture, float2 coords, float2 gridSize, float2 spriteSize = .One)
		{
			float2 textureSize = .(texture.Width, texture.Height);

			float4 uv = .(coords * gridSize, gridSize * spriteSize) / textureSize.XYXY;

			return new SubTexture2D(texture, uv);
		}
	}
}