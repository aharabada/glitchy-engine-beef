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

		[Inline]
		Color HtoRGB(float h)
		{
			var h;
			h = h % 360.0f;

			float x = (1 - Math.Abs((h / 60.0f) % 2 - 1));
			
			Vector3 cStrich;

			if(h < 60)
				cStrich = .(1, x, 0);
			else if(h < 120)
				cStrich = .(x, 1, 0);
			else if(h < 180)
				cStrich = .(0, 1, x);
			else if(h < 240)
				cStrich = .(0, x, 1);
			else if(h < 300)
				cStrich = .(x, 0, 1);
			else
				cStrich = .(1, 0, x);

			cStrich *= 255.0f;

			return .((uint8)cStrich.X, (uint8)cStrich.Y, (uint8)cStrich.Z);
		}

		//[/Inline]
		BlockFace GetVisibleFaces(VoxelChunk chunk, int x, int y, int z)
		{
			BlockFace visibleFaces = .None;
			
			if(z == 0 || chunk.Data[x][y][z - 1] == 0)
				visibleFaces |= .Back;
			if(z == VoxelChunk.SizeZ - 1 || chunk.Data[x][y][z + 1] == 0)
				visibleFaces |= .Front;

			if(x == 0 || chunk.Data[x - 1][y][z] == 0)
				visibleFaces |= .Left;
			if(x == VoxelChunk.SizeX - 1 || chunk.Data[x + 1][y][z] == 0)
				visibleFaces |= .Right;

			if(y == 0 || chunk.Data[x][y - 1][z] == 0)
				visibleFaces |= .Bottom;
			if(y == VoxelChunk.SizeY - 1 || chunk.Data[x][y + 1][z] == 0)
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
				uint16 blockIndex = chunk.Data[x][y][z];

				Vector3 blockPos = .(x, y, z);

				if(blockIndex != 0)
				{
					BlockFace visibleFaces = GetVisibleFaces(chunk, x, y, z);

					if(visibleFaces != .None)
						GenerateBlockModel(blockIndex, blockPos, visibleFaces, vertices, indices, ref lastIndex);
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

			Debug.WriteLine($"Generation: {sw.ElapsedMilliseconds}");

			delete sw;

			return gb;
		}

		Random r = new Random(1337) ~ delete _;
		float f = 0.0f;

		void GenerateBlockModel(uint16 blockIndex, Vector3 blockPosition, BlockFace visibleFaces, List<VertexColorTexture> vertices, List<uint32> indices, ref uint32 lastIndex)
		{
		 	Color c = .Pink;

			if(blockIndex == 1)
				c = .Gray;
			else if(blockIndex == 2)
				c = .SaddleBrown;
			else if(blockIndex == 3)
				c = .Green;

			//Color c = .(blockIndex, blockIndex, blockIndex);

			//c = HtoRGB(f += r.Next(0, 0xBEEF));
			
			if(blockPosition.Y == 63)
				c = .Red;

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
		
		void AddQuadIndices(ref uint32 lastIndex, List<uint32> indices)
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
