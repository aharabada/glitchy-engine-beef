using System.Collections;
using GlitchyEngine.Renderer;

namespace Sandbox.VoxelFun
{
	class BlockTextures
	{
		static List<BlockTexture> _textures = new List<BlockTexture>() ~ DeleteContainerAndItems!(_);

		static TextureAtlas _atlas ~ _?.ReleaseRef();
			
		public static BlockTexture Stone;
		public static BlockTexture Dirt;
		public static BlockTexture GrassTop;
		public static BlockTexture GrassSide;

		public static TextureAtlas Atlas => _atlas;

		public static void Init(GraphicsContext context)
		{
			Stone = RegisterTexture(.. new BlockTexture("Content\\Textures\\Stone.png"));
			Dirt = RegisterTexture(.. new BlockTexture("Content\\Textures\\Dirt.png"));
			GrassTop = RegisterTexture(.. new BlockTexture("Content\\Textures\\GrassTop.png"));
			GrassSide = RegisterTexture(.. new BlockTexture("Content\\Textures\\GrassSide.png"));

			GenerateAtlas(context);
		}

		private static void RegisterTexture(BlockTexture texture)
		{
			_textures.Add(texture);
		}

		static void GenerateAtlas(GraphicsContext context)
		{
			_atlas = new TextureAtlas(context, _textures);

			GlitchyEngine.Renderer.SamplerStateDescription desc = .();
			desc.MagFilter = .Point;
			desc.MinFilter = .Point;
			desc.MipFilter = .Point;
			desc.MipMaxLOD = 0;
			desc.MipMinLOD = 0;
			desc.MaxAnisotropy = 0;

			_atlas.SamplerState = new SamplerState(context, desc)..ReleaseRefNoDelete();
		}
	}
}
