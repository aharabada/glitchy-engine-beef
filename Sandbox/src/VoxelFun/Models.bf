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
			Stone = RegisterModel(Blocks.Stone, .. new BlockModel(.Gray));
			Grass = RegisterModel(Blocks.Grass, .. new BlockModel(.Green));
			Dirt = RegisterModel(Blocks.Dirt, .. new BlockModel(.Brown));
		}

		public static void RegisterModel(Block block, Model model)
		{
			_models.Add(model);
			block.[Friend]_model = model;
		}
	}
}
