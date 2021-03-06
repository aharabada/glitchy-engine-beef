using System.Collections;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using System;
using System.Diagnostics;
using static Sandbox.VoxelFun.VoxelTestLayer;
namespace Sandbox.VoxelFun
{
	enum BlockFace
	{
		case None = 0;
		case Front = 1;
		case Back = 2;
		case Left = 4;
		case Right = 8;
		case Top = 16;
		case Bottom = 32;
		case All = Bottom | Top | Right | Left | Back | Front;

		public BlockFace Opposite
		{
			get
			{
				switch(this)
				{
				case Front:
					return Back;
				case Back:
					return Front;
				case Left:
					return Right;
				case Right:
					return Left;
				case Top:
					return Bottom;
				case Bottom:
					return Top;
				default:
					return None;
				}
			}
		}
	}

	class VoxelGeometryGenerator
	{
		public GraphicsContext Context;
		public VertexLayout Layout;

		BlockFace GetVisibleFaces(VoxelChunk chunk, int x, int y, int z)
		{
			BlockFace visibleFaces = .None;
			
			if(z == 0 || chunk.Data[x][y][z - 1].VisibleNeighbors.HasFlag(.Front))
				visibleFaces |= .Back;
			if(z == VoxelChunk.SizeZ - 1 || chunk.Data[x][y][z + 1].VisibleNeighbors.HasFlag(.Back))
				visibleFaces |= .Front;

			if(x == 0 || chunk.Data[x - 1][y][z].VisibleNeighbors.HasFlag(.Right))
				visibleFaces |= .Left;
			if(x == VoxelChunk.SizeX - 1 || chunk.Data[x + 1][y][z].VisibleNeighbors.HasFlag(.Left))
				visibleFaces |= .Right;

			if(y == 0 || chunk.Data[x][y - 1][z].VisibleNeighbors.HasFlag(.Top))
				visibleFaces |= .Bottom;
			if(y == VoxelChunk.SizeY - 1 || chunk.Data[x][y + 1][z].VisibleNeighbors.HasFlag(.Bottom))
				visibleFaces |= .Top;

			return visibleFaces;
		}

		public GeometryBinding GenerateGeometry(VoxelChunk chunk)
		{
			List<VertexColorTexture> vertices = scope List<VertexColorTexture>();
			List<uint32> indices = scope List<uint32>();
			uint32 lastIndex = 0;

			Stopwatch sw = .StartNew();

		   	for(int x < VoxelChunk.SizeX)
		   	for(int y < VoxelChunk.SizeY)
		   	for(int z < VoxelChunk.SizeZ)
			{
				Block block = chunk.Data[x][y][z];

				Vector3 blockPos = .(x, y, z);

				if(block != Blocks.Air)
				{
					BlockFace visibleFaces = GetVisibleFaces(chunk, x, y, z);

					if(visibleFaces != .None)
						GenerateBlockModel(block, blockPos, visibleFaces, vertices, indices, ref lastIndex);
				}
			}

			GeometryBinding gb;

			if(indices.Count > 0)
			{
				VertexBuffer vb = new VertexBuffer(Context, typeof(VertexColorTexture), (.)vertices.Count, .Default, .None);
				vb.SetData<VertexColorTexture>(vertices);

				IndexBuffer ib = new IndexBuffer(Context, (.)indices.Count, .Default, .None, .Index32Bit);
				ib.SetData<uint32>(indices);

				gb = new GeometryBinding(Context);
				gb.SetVertexBufferSlot(vb, 0);
				gb.SetIndexBuffer(ib);
				gb.SetPrimitiveTopology(.TriangleList);
				gb.SetVertexLayout(Layout);

				vb.ReleaseRef();
				ib.ReleaseRef();
			}
			else
			{
				gb = null;
			}

			sw.Stop();

			Debug.WriteLine($"Geometry Generation: {sw.ElapsedMilliseconds}");

			delete sw;

			return gb;
		}

		Random r = new Random(1337) ~ delete _;
		float f = 0.0f;

		public static void GenerateBlockModel(Block block, Vector3 blockPosition, BlockFace visibleFaces, List<VertexColorTexture> vertices, List<uint32> indices, ref uint32 lastIndex)
		{
		 	Color c = block.Color;

			if(visibleFaces.HasFlag(.Back))
			{
				vertices.Add(VertexColorTexture(blockPosition + .(0, 0, 0), c, .UnitY));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 0, 0), c, .One));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 1, 0), c, .UnitX));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 1, 0), c, .Zero));

				AddQuadIndices(ref lastIndex, indices);
			}

			if(visibleFaces.HasFlag(.Top))
			{
				vertices.Add(VertexColorTexture(blockPosition + .(0, 1, 0), c, .UnitY));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 1, 0), c, .One));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 1, 1), c, .UnitX));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 1, 1), c, .Zero));

				AddQuadIndices(ref lastIndex, indices);
			}

			if(visibleFaces.HasFlag(.Bottom))
			{
				vertices.Add(VertexColorTexture(blockPosition + .(0, 0, 1), c, .UnitY));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 0, 1), c, .One));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 0, 0), c, .UnitX));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 0, 0), c, .Zero));

				AddQuadIndices(ref lastIndex, indices);
			}
			
			if(visibleFaces.HasFlag(.Front))
			{
				vertices.Add(VertexColorTexture(blockPosition + .(1, 0, 1), c, .UnitY));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 0, 1), c, .One));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 1, 1), c, .UnitX));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 1, 1), c, .Zero));

				AddQuadIndices(ref lastIndex, indices);
			}
			
			if(visibleFaces.HasFlag(.Right))
			{
				vertices.Add(VertexColorTexture(blockPosition + .(1, 0, 0), c, .UnitY));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 0, 1), c, .One));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 1, 1), c, .UnitX));
				vertices.Add(VertexColorTexture(blockPosition + .(1, 1, 0), c, .Zero));

				AddQuadIndices(ref lastIndex, indices);
			}
			
			if(visibleFaces.HasFlag(.Left))
			{
				vertices.Add(VertexColorTexture(blockPosition + .(0, 0, 1), c, .UnitY));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 0, 0), c, .One));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 1, 0), c, .UnitX));
				vertices.Add(VertexColorTexture(blockPosition + .(0, 1, 1), c, .Zero));

				AddQuadIndices(ref lastIndex, indices);
			}
		}
		
		static void AddQuadIndices(ref uint32 lastIndex, List<uint32> indices)
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
}
