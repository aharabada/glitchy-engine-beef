using System.Collections;
using GlitchyEngine.Math;
using static Sandbox.VoxelFun.VoxelTestLayer;
namespace Sandbox.VoxelFun
{
	abstract class Model
	{
		public abstract void GenerateGeometry(Block block, Vector3 blockPosition, BlockFace visibleFaces, List<VertexColorTexture> vertices, List<uint32> indices, ref uint32 lastIndex);

		protected static void AddQuadIndices(ref uint32 lastIndex, List<uint32> indices)
		{
			uint32[6] inds;
			inds[0] = lastIndex;
			inds[1] = lastIndex + 1;
			inds[2] = lastIndex + 2;

			inds[3] = lastIndex + 2;
			inds[4] = lastIndex + 3;
			inds[5] = lastIndex;

			indices.AddRange(inds);
			lastIndex += 4;
		}
	}

	class BlockModel : Model
	{
		Color _color;

		public this(Color color)
		{
			_color = color;
		}

		public override void GenerateGeometry(Block block, Vector3 blockPosition, BlockFace visibleFaces, List<VertexColorTexture> vertices, List<uint32> indices, ref uint32 lastIndex)
		{
			if(visibleFaces.HasFlag(.Back))
			{
				vertices.Add(VertexColorTexture(blockPosition + .(0, 0, 0), _color, .UnitY));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 0, 0), _color, .One));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 1, 0), _color, .UnitX));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 1, 0), _color, .Zero));
	
				AddQuadIndices(ref lastIndex, indices);
			}
	
			if(visibleFaces.HasFlag(.Top))
			{
				vertices.Add(VertexColorTexture(blockPosition + .(0, 1, 0), _color, .UnitY));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 1, 0), _color, .One));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 1, 1), _color, .UnitX));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 1, 1), _color, .Zero));
	
				AddQuadIndices(ref lastIndex, indices);
			}
	
			if(visibleFaces.HasFlag(.Bottom))
			{
				vertices.Add(VertexColorTexture(blockPosition + .(0, 0, 1), _color, .UnitY));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 0, 1), _color, .One));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 0, 0), _color, .UnitX));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 0, 0), _color, .Zero));
	
				AddQuadIndices(ref lastIndex, indices);
			}
	
			if(visibleFaces.HasFlag(.Front))
			{
				vertices.Add(VertexColorTexture(blockPosition + .(1, 0, 1), _color, .UnitY));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 0, 1), _color, .One));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 1, 1), _color, .UnitX));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 1, 1), _color, .Zero));
	
				AddQuadIndices(ref lastIndex, indices);
			}
	
			if(visibleFaces.HasFlag(.Right))
			{
				vertices.Add(VertexColorTexture(blockPosition + .(1, 0, 0), _color, .UnitY));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 0, 1), _color, .One));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 1, 1), _color, .UnitX));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 1, 0), _color, .Zero));
	
				AddQuadIndices(ref lastIndex, indices);
			}
	
			if(visibleFaces.HasFlag(.Left))
			{
				vertices.Add(VertexColorTexture(blockPosition + .(0, 0, 1), _color, .UnitY));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 0, 0), _color, .One));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 1, 0), _color, .UnitX));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 1, 1), _color, .Zero));
	
				AddQuadIndices(ref lastIndex, indices);
			}
		}
	}
}
