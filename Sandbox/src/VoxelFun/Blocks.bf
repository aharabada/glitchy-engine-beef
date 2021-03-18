using System;
using System.Collections;
namespace Sandbox.VoxelFun
{
	static class Blocks
	{
		static uint16 _sLastId;
		static List<Block> _blocks = new List<Block>() ~ DeleteContainerAndItems!(_);

		/// Air is a special Block. It defines the absence of a block.
		public static Block Air;

		public static Block Stone;
		public static Block Grass;
		public static Block Dirt;

		public static void Init()
		{
			Air = RegisterBlock(.. new Block(.All));
			Stone = RegisterBlock(.. new Block());
			Grass = RegisterBlock(.. new Block());
			Dirt = RegisterBlock(.. new Block());
		}

		private static void RegisterBlock(Block block)
		{
			block.[Friend]_blockID = _sLastId;
			_sLastId++;
			_blocks.Add(block);
		}

		public static Block GetFromId(int id)
		{
			return _blocks[id];
		}
	}
}
