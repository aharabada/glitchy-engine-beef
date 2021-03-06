using System;
using System.Collections;
namespace Sandbox.VoxelFun
{
	static class Blocks
	{
		static uint16 _sLastId;
		static List<Block> _blocks = new List<Block>() ~ DeleteContainerAndItems!(_);

		/// Air is a special Block. It defines the absence of a block.
		public static Block Air = RegisterBlock(.. new Block(.White, .All));

		public static Block Stone = RegisterBlock(.. new Block(.Gray));
		public static Block Grass = RegisterBlock(.. new Block(.Green));
		public static Block Dirt = RegisterBlock(.. new Block(.Brown));

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
