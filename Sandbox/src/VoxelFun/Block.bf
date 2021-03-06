using GlitchyEngine.Math;
namespace Sandbox.VoxelFun
{
	class Block
	{
		private uint16 _blockID;

		public uint16 ID => _blockID;

		public Color Color {get;}

		public BlockFace VisibleNeighbors {get;}

		public this(Color color, BlockFace visibleNeighbors = .None)
		{
			Color = color;
			VisibleNeighbors = visibleNeighbors;
		}
	}
}
