namespace Sandbox.VoxelFun
{
	public struct VoxelChunk
	{
		public const int SizeX = 16;
		public const int SizeY = 256;
		public const int SizeZ = 16;

		public uint8[SizeX][SizeY][SizeZ] Data;
	}
}
