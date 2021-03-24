using System;
using System.Collections;

namespace Sandbox.VoxelFun
{
	static class Models
	{
		static List<Model> _models = new List<Model>() ~ DeleteContainerAndItems!(_);

		public static Model Stone;
		public static Model Grass;
		public static Model Dirt;

		public static void Init()
		{
			Stone = RegisterModel(Blocks.Stone, .. new BlockModel(.White, BlockTextures.Stone));
			Grass = RegisterModel(Blocks.Grass, .. new BlockModel(.White, BlockTextures.GrassTop, BlockTextures.GrassSide, BlockTextures.Dirt));
			Dirt = RegisterModel(Blocks.Dirt, .. new BlockModel(.White, BlockTextures.Dirt));
		}

		public static void RegisterModel(Block block, Model model)
		{
			_models.Add(model);
			block.[Friend]_model = model;
		}
	}
}
