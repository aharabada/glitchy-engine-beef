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
using GlitchyEngine;
using GlitchyEngine.Threading;

namespace Sandbox.VoxelFun
{
	public class Chunk
	{
		public ChunkManager ChunkManager;
		public GeometryBinding Geometry ~ _?.ReleaseRef();

		public VoxelChunk Data;
		public Matrix Transform;
		public Int32_3 Position;
		public Int32_3 Coordinate;

		private bool _isDirty;
		private bool _isGeometryDirty;

		public bool IsDirty => _isDirty;

		public bool IsGeometryDirty
		{
			get => _isGeometryDirty;
			set => _isGeometryDirty = value;
		}

		public void SetBlock(Int32_3 coordinate, Block blockId)
		{
			Log.EngineLogger.AssertDebug(coordinate.X >= 0 && coordinate.Y >= 0 && coordinate.Z >= 0 && coordinate.X < VoxelChunk.Size.X && coordinate.Y < VoxelChunk.Size.Y && coordinate.Z < VoxelChunk.Size.Z, "Specified coordinate is out of range.");

			Data.Data[coordinate.X][coordinate.Y][coordinate.Z] = blockId;

			_isDirty = true;
			_isGeometryDirty = true;
			ChunkManager.[Friend]chunkPosLock.Exit();
		}

		public Block GetBlock(Int32_3 coordinate)
		{
			Log.EngineLogger.AssertDebug(coordinate.X >= 0 && coordinate.Y >= 0 && coordinate.Z >= 0 && coordinate.X < VoxelChunk.Size.X && coordinate.Y < VoxelChunk.Size.Y && coordinate.Z < VoxelChunk.Size.Z, "Specified coordinate is out of range.");

			return Data.Data[coordinate.X][coordinate.Y][coordinate.Z];
		}

		public void Serialize(Stream stream)
		{
			uint16[VoxelChunk.SizeX][VoxelChunk.SizeY][VoxelChunk.SizeZ] rawData = ?;

			for(int x = 0; x < VoxelChunk.SizeX; x++)
			for(int y = 0; y < VoxelChunk.SizeY; y++)
			for(int z = 0; z < VoxelChunk.SizeZ; z++)
			{
				rawData[x][y][z] = Data.Data[x][y][z].ID;
			}
			stream.Write(rawData);
			_isDirty = false;
		}
	}

	public class ChunkManager
	{
		GraphicsContext _context ~ _?.ReleaseRef();

		int _viewDistance = 8;
		private World _world;

		private String _chunkBasePath ~ delete _;

		Dictionary<Int32_3, Chunk> _chunks = new .() ~ delete _;

		private HashSet<Int32_3> _generatingChunks = new .() ~ delete _;
		private Monitor _generatingChunksLock = new .() ~ delete _;

		public Texture2D Texture ~ _?.ReleaseRef();
		public Effect TextureEffect ~ _?.ReleaseRef();
		
		VoxelGeometryGenerator voxelGeoGen = new VoxelGeometryGenerator() ~ delete _;

		Thread chunkLoader;
		bool stopChunkLoader;
		Monitor chunkListLock = new Monitor() ~ delete _;

		Int32_3 chunkPosition;
		Int32_3 oldChunkPosition = .(Int.MaxValue, Int.MaxValue, Int.MaxValue);

		Monitor chunkPosLock = new Monitor() ~ delete _;

		Monitor chunkPosChanged = new Monitor()..Enter() ~ delete _;

		public World World => _world;
		
		public delegate void ChunkLoadedHandler(Int32_3 chunkCoordinate);

		Event<ChunkLoadedHandler> _chunkLoaded ~ _.Dispose();
		Monitor _chunkLoadedLock = new Monitor() ~ delete _;
		
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

			chunkLoader = new Thread(new => ChunkLoaderThread_Entry);
			chunkLoader.Start();

		}

		public ~this()
		{
			stopChunkLoader = true;

			chunkLoader.Join();

			// Unload (and save) all chunks
			for(var pair in _chunks)
			{
				UnloadChunk(pair.value);
			}
		}

		/**
		 * Returns whether or not the chunk with the given coordinate is currently loaded.
		 */
		[Inline]
		public bool IsChunkLoaded(Int32_3 chunkCoordinate)
		{
			using(chunkListLock.Enter())
			{
				return _chunks.ContainsKey(chunkCoordinate);
			}
		}

		/**
		 * Returns the chunk with the given chunk coordinate or null if the chunk isn't loaded.
		 */
		[Inline]
		public Chunk GetChunk(Int32_3 chunkCoordinate)
		{
			using(chunkListLock.Enter())
			{
				return _chunks.TryGetValue(chunkCoordinate, let chunk) ? chunk : null;
			}
		}
		
		/**
		 * Loads and returns the chunk with the given coordinate. If the chunk doesn't exist it will be generated.
		 * @param chunkCoordinate The coordinate of the chunk to load.
		 * @param noBlocking If set to true this method will not wait if the chunk cannot be loaded right now (because it is currently being loaded by another thread);
		 *					 otherwise the method will block until the chunk has been loaded.
		 * @returns The loaded chunk. If noBlocking is set to true and the chunk cannot be obtained right now the return value will be null.
		 */
		public Chunk LoadChunk(Int32_3 chunkCoordinate, bool noBlocking = false)
		{
			Chunk chunk = GetChunk(chunkCoordinate);

			if(chunk == null)
			{
				// Add chunk coordinate to generating list
				// If it could be added, we have to generate it ourselves, otherwise we have to wait for the other thread to finish.
				bool alreadyInList = false;
				using(_generatingChunksLock.Enter())
				{
					alreadyInList = !_generatingChunks.Add(chunkCoordinate);
				}

				if(!alreadyInList)
				{
					chunk = new Chunk();
					chunk.ChunkManager = this;
					chunk.Coordinate = chunkCoordinate;
					chunk.Position = chunkCoordinate * .(VoxelChunk.SizeX, VoxelChunk.SizeY, VoxelChunk.SizeZ);
					chunk.Transform = .Translation(chunk.Position.X, chunk.Position.Y, chunk.Position.Z);

					if(LoadChunkFromFile(chunkCoordinate, chunk) case .Err)
					{
						GenTestChunk(chunk);
						SaveChunkToFile(chunk);
					}

					GenChunkGeo(chunk);

					using(chunkListLock.Enter())
					{
						if(!_chunks.TryAdd(chunkCoordinate, chunk))
						{
							chunk = LoadChunk(chunkCoordinate);
						}
					}

					using(_generatingChunksLock.Enter())
					{
						_generatingChunks.Remove(chunkCoordinate);
					}

					// Raise chunk loaded event (this will wake up all calls of LoadChunk waiting for our chunk)
					using(_chunkLoadedLock.Enter())
					{
						_chunkLoaded.Invoke(chunkCoordinate);
					}
				}
				else if(!noBlocking)
				{
					Semaphore semaphore = new Semaphore(0);
					defer delete semaphore;

					// event handler will increase semaphore as soon as our requested chunk is loaded.
					ChunkLoadedHandler eventHandler = scope (coordinate) =>
						{
							if(coordinate == chunkCoordinate)
							{
								semaphore.Unlock();
							}
						};

					// register event listener
					using(_chunkLoadedLock.Enter())
					{
						_chunkLoaded.Add(eventHandler);
					}
					
					Log.ClientLogger.Trace($"Sleeping until chunk ({chunkCoordinate}) has been generated...");

					// wait for semaphore to be released (in the event handler)
					semaphore.Lock();

					// unregister event handler
					using(_chunkLoadedLock.Enter())
					{
						_chunkLoaded.Remove(eventHandler);
					}

					// retry loading the chunk
					chunk = LoadChunk(chunkCoordinate);
				}
			}

			return chunk;
		}

		void SetChunkPos(Int32_3 chunkPos)
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

			Int32_3 p = (Int32_3)chunkPosition;
			p.Y = 0;

			SetChunkPos(p);
		}

		/**
		 * Entrypoint for the chunk loader thread.
		 */
		void ChunkLoaderThread_Entry()
		{
			Int32_3 curChunkPosition = .(0, 0, 0);
			Int32_3 oldChunkPosition = .(Int.MaxValue, Int.MaxValue, Int.MaxValue);

			while(!stopChunkLoader)
			{
				// Wait for chunkPos to change
				chunkPosChanged.Enter();
				
				using(chunkPosLock.Enter())
				{
					curChunkPosition = chunkPosition;
				}

				// Position didn't change -> skip
				//if(curChunkPosition == oldChunkPosition)
				//	continue;

				ChunkLoaderThread_GenerateChunks(curChunkPosition);

				oldChunkPosition = curChunkPosition;
			}
		}

		private void UnloadChunk(Chunk chunk)
		{
			if(chunk.IsDirty)
			{
				SaveChunkToFile(chunk);
			}

			using(chunkListLock.Enter())
			{
				_chunks.Remove(chunk.Coordinate);
				delete chunk;
			}
		}

		public void ChunkLoaderThread_GenerateChunks(Int32_3 chunkPos)
		{
			for(var chunk in _chunks)
			{
				Int32_3 dist = (chunk.key - chunkPos).Abs();

				if(dist.X > _viewDistance || dist.Z > _viewDistance)
				{
					UnloadChunk(chunk.value);
				}
				else if(chunk.value.IsGeometryDirty)
				{
					GenChunkGeo(chunk.value);
				}
			}
			
			Int32_3 chunkCoordinate = (Int32_3)chunkPos;
			int x = 0, z = 0;
			for(int r = 1; r < _viewDistance; r++)
			{
				for(; x < r; x++, chunkCoordinate.X++)
				{
					LoadChunk(chunkCoordinate, true);
				}

				for(; z < r; z++, chunkCoordinate.Z++)
				{
					LoadChunk(chunkCoordinate, true);
				}

				for(; x > -r; x--, chunkCoordinate.X--)
				{
					LoadChunk(chunkCoordinate, true);
				}
				
				for(; z > -r; z--, chunkCoordinate.Z--)
				{
					LoadChunk(chunkCoordinate, true);
				}
			}
		}

		Result<void> LoadChunkFromFile(Int32_3 chunkCoordinate, Chunk outChunk)
		{
			String chunkFileName = scope String(_chunkBasePath);
			chunkFileName.AppendF($"{chunkCoordinate.X}_{chunkCoordinate.Y}_{chunkCoordinate.Z}.cdata");

			if(!File.Exists(chunkFileName))
				return .Err;
			
			uint16[VoxelChunk.SizeX][VoxelChunk.SizeY][VoxelChunk.SizeZ] rawData;

			FileStream fs = scope FileStream();

			fs.Open(chunkFileName, .Read, .Read);

			rawData = fs.Read<decltype(rawData)>();

			fs.Close();

			for(int x = 0; x < VoxelChunk.SizeX; x++)
			for(int y = 0; y < VoxelChunk.SizeY; y++)
			for(int z = 0; z < VoxelChunk.SizeZ; z++)
			{
				outChunk.Data.Data[x][y][z] = Blocks.GetFromId(rawData[x][y][z]);
			}

			return .Ok;
		}

		Result<void> SaveChunkToFile(Chunk chunk)
		{
			String chunkFileName = scope String(_chunkBasePath);
			chunkFileName.AppendF($"{chunk.Coordinate.X}_{chunk.Coordinate.Y}_{chunk.Coordinate.Z}.cdata");
			
			FileStream fs = scope FileStream();

			fs.Open(chunkFileName, FileMode.Create, .Write);

			chunk.Serialize(fs);

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
				Block stepValue = gradientValue < 0.5f ? Blocks.Stone : Blocks.Air;

				// Note these objects will be invalid
				chunk.Data.Data[x][y][z] = stepValue;
			}

			sw.Stop();

			Debug.WriteLine($"Terrain Generation: {sw.ElapsedMilliseconds}ms");

			delete sw;
		}

		struct GroundLayer
		{
			public int Depth;
			public Block BlockType;
		}

		void GroundLayers(Chunk chunk)
		{
			GroundLayer[3] layers;
			layers[0] = .()
			{
				Depth = 1,
				BlockType = Blocks.Grass
			};
			layers[1] = .()
			{
				Depth = 4,
				BlockType = Blocks.Dirt
			};
			layers[2] = .()
			{
				Depth = 0,
				BlockType = Blocks.Stone
			};

			for(int x < VoxelChunk.SizeX)
			for(int z < VoxelChunk.SizeZ)
			{
				int currentLayer = 0;
				int currentDepth = 0;

				for(int y = VoxelChunk.SizeY - 1; y > 0; y--)
				{
					if(chunk.Data.Data[x][y][z] == Blocks.Air)
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
			var oldGeometry = chunk.Geometry;

			var newGeometry = voxelGeoGen.GenerateGeometry(chunk.Data);

			Interlocked.Store(ref chunk.Geometry, newGeometry);
			chunk.IsGeometryDirty = false;

			oldGeometry?.ReleaseRef();
		}

		public void Draw()
		{
			chunkListLock.Enter();
			for(let pair in _chunks)
			{
				Chunk chunk = pair.value;

				GeometryBinding chunkGeo = Interlocked.Load(ref chunk.Geometry);
				chunkGeo.AddRef();

				if(chunkGeo == null)
					continue;

				Texture.Bind();

				Renderer.Submit(chunk.Geometry, TextureEffect, chunk.Transform);
				chunkGeo.ReleaseRef();
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
