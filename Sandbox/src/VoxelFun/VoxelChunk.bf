using GlitchyEngine.Math;

namespace Sandbox.VoxelFun
{
	public struct VoxelChunk
	{
		public const int SizeX = 16;
		public const int SizeY = 256;
		public const int SizeZ = 16;

		public const Int32_3 Size = .(SizeX, SizeY, SizeZ);
		public const Vector3 VectorSize = .(SizeX, SizeY, SizeZ);

		public Block[SizeX][SizeY][SizeZ] Data;
	}
}
