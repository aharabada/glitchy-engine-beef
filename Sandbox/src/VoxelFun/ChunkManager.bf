using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using System.Diagnostics;
using System;
using System.Collections;
using System.Threading;
using System.Collections;
using GlitchyEngine.ImGui;
using ImGui;
using System.IO;

namespace Sandbox.VoxelFun
{
	public class Chunk
	{
		public GeometryBinding Geometry ~ _?.ReleaseRef();
		public VoxelChunk Data;
		public Matrix Transform;
		public Point3 Position;
	}

	public struct Point3 : IHashable
	{
		public int X, Y, Z;

		public this(int x, int y, int z)
		{
			X = x;
			Y = y;
			Z = z;
		}

		public int GetHashCode()
		{
			return (((X * 39) ^ Y) * 39) ^ Z;
		}

		public static int DistanceSq(Point3 value1, Point3 value2)
		{
			int dstX = value1.X - value2.X;
			int dstY = value1.Y - value2.Y;
			int dstZ = value1.Z - value2.Z;

			return dstX * dstX + dstY * dstY + dstZ * dstZ;
		}

		public static Point3 operator +(Point3 left, Point3 right) => .(left.X + right.X, left.Y + right.Y, left.Z + right.Z);
		public static Point3 operator -(Point3 left, Point3 right) => .(left.X - right.X, left.Y - right.Y, left.Z - right.Z);
		public static Point3 operator *(Point3 left, Point3 right) => .(left.X * right.X, left.Y * right.Y, left.Z * right.Z);

		public Point3 Abs()
		{
			return .(Math.Abs(X), Math.Abs(Y), Math.Abs(Z));
		}

		public static explicit operator Vector3(Point3 point) => .(point.X, point.Y, point.Z);

		public static explicit operator Point3(Vector3 point) => .((int)point.X, (int)point.Y, (int)point.Z);

		public static bool operator ==(Point3 left, Point3 right) => left.X == right.X && left.Y == right.Y && left.Z == right.Z;
		public static bool operator !=(Point3 left, Point3 right) => left.X != right.X || left.Y != right.Y || left.Z != right.Z;
	}

	public class ChunkManager
	{
		GraphicsContext _context ~ _?.ReleaseRef();

		int _viewDistance = 8;
		private World _world;

		private String _chunkBasePath ~ delete _;

		Dictionary<Point3, Chunk> chunks = new .() ~ DeleteDictionaryAndValues!(_);

		public Texture2D Texture ~ _?.ReleaseRef();
		public Effect TextureEffect ~ _?.ReleaseRef();
		
		VoxelGeometryGenerator voxelGeoGen = new VoxelGeometryGenerator() ~ delete _;

		Thread chunkLoader;
		bool stopChunkLoader;
		Monitor chunkListLock = new Monitor() ~ delete _;

		Point3 chunkPosition;
		Point3 oldChunkPosition = .(Int.MaxValue, Int.MaxValue, Int.MaxValue);

		Monitor chunkPosLock = new Monitor() ~ delete _;

		Monitor chunkPosChanged = new Monitor()..Enter() ~ delete _;

		public World World => _world;
		
		public this(GraphicsContext context, VertexLayout vertexLayout, World world)
		{
			_context = context..AddRef();
			_world = world;

			_chunkBasePath = Path.InternalCombine(.. new String(), _world.Directory, "chunks", "");

			if(!Directory.Exists(_chunkBasePath))
			{
				Directory.CreateDirectory(_chunkBasePath);
			}

			voxelGeoGen.Context = _context;
			voxelGeoGen.Layout = vertexLayout;

			chunkLoader = new Thread(new => ChunkLoaderThread);
			chunkLoader.Start();
		}

		public ~this()
		{
			stopChunkLoader = true;

			chunkLoader.Join();
		}

		void SetChunkPos(Point3 chunkPos)
		{
			chunkPosLock.Enter();
			chunkPosition = chunkPos;

			if(oldChunkPosition != chunkPosition)
				chunkPosChanged.Exit();

			chunkPosLock.Exit();
		}

		public void Update(Vector3 cameraPosition)
		{
			Vector3 chunkPosition = cameraPosition / .(VoxelChunk.SizeX, VoxelChunk.SizeY, VoxelChunk.SizeZ);

			Point3 p = (Point3)chunkPosition;
			p.Y = 0;

			SetChunkPos(p);
		}

		void ChunkLoaderThread()
		{
			Point3 curChunkPosition = .(0, 0, 0);
			Point3 oldChunkPosition = .(Int.MaxValue, Int.MaxValue, Int.MaxValue);

			while(!stopChunkLoader)
			{
				// Wait for chunkPos to change
				chunkPosChanged.Enter();
				
				chunkPosLock.Enter();
				curChunkPosition = chunkPosition;
				chunkPosLock.Exit();

				// Position didn't change -> skip
				if(curChunkPosition == oldChunkPosition)
					continue;

				GenerateChunks(curChunkPosition);

				oldChunkPosition = curChunkPosition;
			}
		}

		public void GenerateChunks(Point3 chunkPos)
		{
			for(var chunk in chunks)
			{
				Point3 dist = (chunk.key - chunkPos).Abs();

				if(dist.X > _viewDistance || dist.Z > _viewDistance)
				{
					chunkListLock.Enter();
					delete chunk.value;
					chunks.Remove(chunk.key);
					chunkListLock.Exit();
				}
			}

			for(int x = -_viewDistance; x < _viewDistance; x++)
			//for(int y = -_viewDistance; y < _viewDistance; y++)
			for(int z = -_viewDistance; z < _viewDistance; z++)
			{
				int y = 0;
				Point3 chunkCoordinate = (Point3)chunkPos + .(x, y, z);

				if(!chunks.ContainsKey(chunkCoordinate))
				{
					var chunk = new Chunk();
					chunk.Position = chunkCoordinate * .(VoxelChunk.SizeX, VoxelChunk.SizeY, VoxelChunk.SizeZ);
					chunk.Transform = .Translation(chunk.Position.X, chunk.Position.Y, chunk.Position.Z);

					if(LoadChunkFromFile(chunkCoordinate, chunk) case .Err)
					{
						GenTestChunk(chunk);
						SaveChunkToFile(chunkCoordinate, chunk);
					}

					GenChunkGeo(chunk);

					chunkListLock.Enter();
					chunks.Add(chunkCoordinate, chunk);
					chunkListLock.Exit();
				}
			}
		}

		Result<void> LoadChunkFromFile(Point3 chunkCoordinate, Chunk outChunk)
		{
			String chunkFileName = scope String(_chunkBasePath);
			chunkFileName.AppendF($"{chunkCoordinate.X}_{chunkCoordinate.Y}_{chunkCoordinate.Z}.cdata");

			if(!File.Exists(chunkFileName))
				return .Err;

			FileStream fs = scope FileStream();

			fs.Open(chunkFileName, .Read, .Read);

			outChunk.Data = fs.Read<VoxelChunk>();

			fs.Close();

			return .Ok;
		}

		Result<void> SaveChunkToFile(Point3 chunkCoordinate, Chunk outChunk)
		{
			String chunkFileName = scope String(_chunkBasePath);
			chunkFileName.AppendF($"{chunkCoordinate.X}_{chunkCoordinate.Y}_{chunkCoordinate.Z}.cdata");

			FileStream fs = scope FileStream();

			fs.Open(chunkFileName, FileMode.Create, .Write);

			fs.Write(outChunk.Data);

			fs.Close();

			return .Ok;
		}

		struct GeneratorSettings
		{
			public int32 ElevationOctaves = 5;
			public float ElevationFrequency = 0.0075f;
			public float ElevationLacunarity = 2f;
			public float ElevationGain = 0.5f;

			public Vector2 DetailAmplitude = .(32, 32);

			public int32 TerrainFloorHeight = 128;
			// The amplitude of the hills (eg. how high hills are and how deep valleys are)
			public int32 TerrainAmplitude = 48;
		}

		void GenerateTerrain(Chunk chunk)
		{
			Stopwatch sw = .StartNew();

			GeneratorSettings settings = .();
			//settings.ElevationFrequency

			let groundNoise = scope FastNoiseLite.FastNoiseLite();
			groundNoise.SetFractalType(.FBm);
			groundNoise.SetFractalOctaves(settings.ElevationOctaves);
			groundNoise.SetFractalLacunarity(settings.ElevationLacunarity);
			groundNoise.SetFractalGain(settings.ElevationGain);
			groundNoise.SetFrequency(settings.ElevationFrequency);
			
			for(int x < VoxelChunk.SizeX)
			for(int y < VoxelChunk.SizeY)
			for(int z < VoxelChunk.SizeZ)
			{
				float cx = x + chunk.Position.X;
				float cy = y + chunk.Position.Y;
				float cz = z + chunk.Position.Z;

				cx += groundNoise.GetNoise(cz * 0.5f, cy) * settings.DetailAmplitude.X;
				cz += groundNoise.GetNoise(cy, cx * 0.5f) * settings.DetailAmplitude.Y;

				cy += groundNoise.GetNoise(cx, cz) * settings.TerrainAmplitude;

				float gradientValue = cy / (float)(settings.TerrainFloorHeight * 2 - 1);

				// determine whether or not gradient value is air
				uint8 stepValue = gradientValue < 0.5f ? 1 : 0;

				chunk.Data.Data[x][y][z] = stepValue;
			}

			sw.Stop();

			Debug.WriteLine($"Terrain Generation: {sw.ElapsedMilliseconds}ms");

			delete sw;
		}

		struct GroundLayer
		{
			public int Depth;
			public uint8 BlockType;
		}

		void GroundLayers(Chunk chunk)
		{
			GroundLayer[3] layers;
			layers[0] = .()
			{
				Depth = 1,
				BlockType = 3
			};
			layers[1] = .()
			{
				Depth = 4,
				BlockType = 2
			};
			layers[2] = .()
			{
				Depth = 0,
				BlockType = 1
			};

			for(int x < VoxelChunk.SizeX)
			for(int z < VoxelChunk.SizeZ)
			{
				int currentLayer = 0;
				int currentDepth = 0;

				for(int y = VoxelChunk.SizeY - 1; y > 0; y--)
				{
					if(chunk.Data.Data[x][y][z] == 0)
					{
						currentDepth--;
						
						if(currentDepth < 0)
						{
							currentDepth = 0;

							currentLayer--;

							if(currentLayer < 0)
								currentLayer = 0;
						}
					}
					else
					{
						chunk.Data.Data[x][y][z] = layers[currentLayer].BlockType;

						currentDepth++;

						if(currentDepth >= layers[currentLayer].Depth)
						{
							if(currentLayer >= layers.Count - 1)
							{
								currentLayer = layers.Count - 1;
							}
							else
							{
								currentDepth = 0;
								currentLayer++;
							}
						}
					}
				}
			}
		}

		void GenTestChunk(Chunk chunk)
		{
			GenerateTerrain(chunk);
			GroundLayers(chunk);
		}

		void GenChunkGeo(Chunk chunk)
		{
			chunk.Geometry?.ReleaseRef();
			chunk.Geometry = voxelGeoGen.GenerateGeometry(chunk.Data);
		}

		public void Draw()
		{
			chunkListLock.Enter();
			for(let pair in chunks)
			{
				Chunk chunk = pair.value;

				if(chunk?.Geometry == null)
					continue;

				Texture.Bind();

				Renderer.Submit(chunk.Geometry, TextureEffect, chunk.Transform);
			}
			chunkListLock.Exit();
		}
		
		public void OnImGuiRender()
		{
			ImGui.Begin("Voxel Manager");

			int32 oldVd = (.)_viewDistance;

			ImGui.DragInt("View distance", (.)&_viewDistance, 1.0f, 1, 1000);

			if(oldVd != _viewDistance)
				chunkPosChanged.Exit();

			ImGui.End();
		}
	}
}
