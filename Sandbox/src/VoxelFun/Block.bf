using GlitchyEngine.Math;
using GlitchyEngine;
namespace Sandbox.VoxelFun
{
	class Block
	{
		private Model _model;

		private uint16 _blockID;

		public uint16 ID => _blockID;

		public Model Model => _model;

		public BlockFace VisibleNeighbors {get;}

		public this(BlockFace visibleNeighbors = .None)
		{
			VisibleNeighbors = visibleNeighbors;
		}

		/**
		 * This method will be called when the block is being destroyed by the player.
		 * @param blockCoordinate The coordinate the block is at.
		 */
		public virtual void OnBreaking(Int32_3 blockCoordinate)
		{
			Log.ClientLogger.Info($"I broke. {{{blockCoordinate}}}");
		}

		/**
		 * This method will be called when the block is being placed by the player.
		 * @param blockCoordinate The coordinate the block is at.
		 */
		public virtual void OnPlacing(Int32_3 blockCoordinate)
		{
			Log.ClientLogger.Info($"I broke. {{{blockCoordinate}}}");
		}
	}
}
