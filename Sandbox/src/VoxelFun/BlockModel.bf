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

		BlockTexture _textureTop;
		BlockTexture _textureSide;
		BlockTexture _textureBottom;
		

		public this(Color color)
		{
			_color = color;

			bottomCoords = sideCoords = topCoords = (.Zero, .UnitX, .UnitY, .One);
		}

		public this(Color color, BlockTexture texture) : this(color, texture, texture, texture)
		{
		}
		
		public this(Color color, BlockTexture topTexture, BlockTexture sideTexture, BlockTexture bottomTexture)
		{
			_color = color;
			_textureTop = topTexture;
			_textureSide = sideTexture;
			_textureBottom = bottomTexture;

			CalculateTexCoords();
		}

		typealias TexCoords = (Vector2 Zero, Vector2 UnitX, Vector2 UnitY, Vector2 One);

		TexCoords topCoords;
		TexCoords sideCoords;
		TexCoords bottomCoords;

		private void CalculateTexCoords()
		{
			topCoords = GetQuadCoords(_textureTop);
			sideCoords = GetQuadCoords(_textureSide);
			bottomCoords = GetQuadCoords(_textureBottom);
		}

		private TexCoords GetQuadCoords(BlockTexture texture)
		{
			TexCoords coords;

			coords.UnitX = texture.TransformTexCoords(.UnitX);
			coords.UnitY = texture.TransformTexCoords(.UnitY);
			coords.Zero = texture.TransformTexCoords(.Zero);
			coords.One = texture.TransformTexCoords(.One);

			return coords;
		}

		public override void GenerateGeometry(Block block, Vector3 blockPosition, BlockFace visibleFaces, List<VertexColorTexture> vertices, List<uint32> indices, ref uint32 lastIndex)
		{

			if(visibleFaces.HasFlag(.Back))
			{
				vertices.Add(VertexColorTexture(blockPosition + .(0, 0, 0), _color, sideCoords.UnitY));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 0, 0), _color, sideCoords.One));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 1, 0), _color, sideCoords.UnitX));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 1, 0), _color, sideCoords.Zero));
	
				AddQuadIndices(ref lastIndex, indices);
			}
	
			if(visibleFaces.HasFlag(.Top))
			{
				vertices.Add(VertexColorTexture(blockPosition + .(0, 1, 0), _color, topCoords.UnitY));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 1, 0), _color, topCoords.One));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 1, 1), _color, topCoords.UnitX));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 1, 1), _color, topCoords.Zero));
	
				AddQuadIndices(ref lastIndex, indices);
			}
	
			if(visibleFaces.HasFlag(.Bottom))
			{
				vertices.Add(VertexColorTexture(blockPosition + .(0, 0, 1), _color, bottomCoords.UnitY));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 0, 1), _color, bottomCoords.One));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 0, 0), _color, bottomCoords.UnitX));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 0, 0), _color, bottomCoords.Zero));
	
				AddQuadIndices(ref lastIndex, indices);
			}
	
			if(visibleFaces.HasFlag(.Front))
			{
				vertices.Add(VertexColorTexture(blockPosition + .(1, 0, 1), _color, sideCoords.UnitY));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 0, 1), _color, sideCoords.One));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 1, 1), _color, sideCoords.UnitX));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 1, 1), _color, sideCoords.Zero));
	
				AddQuadIndices(ref lastIndex, indices);
			}
	
			if(visibleFaces.HasFlag(.Right))
			{
				vertices.Add(VertexColorTexture(blockPosition + .(1, 0, 0), _color, sideCoords.UnitY));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 0, 1), _color, sideCoords.One));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 1, 1), _color, sideCoords.UnitX));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 1, 0), _color, sideCoords.Zero));
	
				AddQuadIndices(ref lastIndex, indices);
			}
	
			if(visibleFaces.HasFlag(.Left))
			{
				vertices.Add(VertexColorTexture(blockPosition + .(0, 0, 1), _color, sideCoords.UnitY));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 0, 0), _color, sideCoords.One));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 1, 0), _color, sideCoords.UnitX));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 1, 1), _color, sideCoords.Zero));
	
				AddQuadIndices(ref lastIndex, indices);
			}
		}
	}
}
