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

		BlockFace GetVisibleFaces(VoxelChunk chunk, int x, int y, int z, Chunk[3][3] chunks)
		{
			BlockFace visibleFaces = .None;

			// Back
			int idx = z;
			Chunk readChunk = chunks[1][1];

			if(idx == 0)
			{
				readChunk = chunks[1][0];
				idx = VoxelChunk.Size.Z;
			}

			if(readChunk == null || readChunk.Data.Data[x][y][idx - 1].VisibleNeighbors.HasFlag(.Front))
				visibleFaces |= .Back;
			
			// Front
			idx = z + 1;
			readChunk = chunks[1][1];

			if(idx == VoxelChunk.Size.Z)
			{
				readChunk = chunks[1][2];
				idx = 0;
			}

			if(readChunk == null || readChunk.Data.Data[x][y][idx].VisibleNeighbors.HasFlag(.Back))
				visibleFaces |= .Front;
			
			// Left
			idx = x;
			readChunk = chunks[1][1];

			if(idx == 0)
			{
				readChunk = chunks[0][1];
				idx = VoxelChunk.Size.X;
			}

			if(readChunk == null || readChunk.Data.Data[idx - 1][y][z].VisibleNeighbors.HasFlag(.Right))
				visibleFaces |= .Left;
			
			// Right
			idx = x + 1;
			readChunk = chunks[1][1];

			if(idx == VoxelChunk.Size.X)
			{
				readChunk = chunks[2][1];
				idx = 0;
			}

			if(readChunk == null || readChunk.Data.Data[idx][y][z].VisibleNeighbors.HasFlag(.Left))
				visibleFaces |= .Right;
			
			// TODO: implement for top and bottom as we have 3D chunks
			if(y == 0 || chunk.Data[x][y - 1][z].VisibleNeighbors.HasFlag(.Top))
				visibleFaces |= .Bottom;
			if(y == VoxelChunk.SizeY - 1 || chunk.Data[x][y + 1][z].VisibleNeighbors.HasFlag(.Bottom))
				visibleFaces |= .Top;

			/*
			if(x == 0 || chunk.Data[x - 1][y][z].VisibleNeighbors.HasFlag(.Right))
				visibleFaces |= .Left;
			if(x == VoxelChunk.SizeX - 1 || chunk.Data[x + 1][y][z].VisibleNeighbors.HasFlag(.Left))
				visibleFaces |= .Right;

			if(y == 0 || chunk.Data[x][y - 1][z].VisibleNeighbors.HasFlag(.Top))
				visibleFaces |= .Bottom;
			if(y == VoxelChunk.SizeY - 1 || chunk.Data[x][y + 1][z].VisibleNeighbors.HasFlag(.Bottom))
				visibleFaces |= .Top;
			*/
			return visibleFaces;
		}

		public GeometryBinding GenerateGeometry(Chunk chunk)
		{
			List<VertexColorTexture> vertices = scope List<VertexColorTexture>();
			List<uint32> indices = scope List<uint32>();
			uint32 lastIndex = 0;

			Stopwatch sw = .StartNew();

			var chunkData = chunk.Data.Data;

			Chunk[3][3] chunks;

			var coord = chunk.Coordinate;

			// left
			coord.X -= 1;
			chunks[0][1] = chunk.ChunkManager.GetChunk(coord);
			if(chunks[0][1] == null)
			{
				// TODO: register reload when neighbor generated
				chunk._reqiredNeighbors |= .Left;
			}

			// back
			coord.X += 1;
			coord.Z -= 1;
			chunks[1][0] = chunk.ChunkManager.GetChunk(coord);
			if(chunks[1][0] == null)
			{
				// TODO: register reload when neighbor generated
				chunk._reqiredNeighbors |= .Back;
			}

			// center
			chunks[1][1] = chunk;
			
			// front
			coord.Z += 2;
			chunks[1][2] = chunk.ChunkManager.GetChunk(coord);
			if(chunks[1][2] == null)
			{
				// TODO: register reload when neighbor generated
				chunk._reqiredNeighbors |= .Front;
			}

			// right
			coord.X += 1;
			coord.Z -= 1;
			chunks[2][1] = chunk.ChunkManager.GetChunk(coord);
			if(chunks[2][1] == null)
			{
				// TODO: register reload when neighbor generated
				chunk._reqiredNeighbors |= .Right;
			}

			for(int x < VoxelChunk.SizeX)
		   	for(int y < VoxelChunk.SizeY)
		   	for(int z < VoxelChunk.SizeZ)
			{
				Block block = chunkData[x][y][z];

				Vector3 blockPos = .(x, y, z);

				if(block != Blocks.Air)
				{
					BlockFace visibleFaces = GetVisibleFaces(chunk.Data, x, y, z, chunks);

					if(visibleFaces != .None)
						block.Model.GenerateGeometry(block, blockPos, visibleFaces, vertices, indices, ref lastIndex);
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
	}
}
