using System;
using System.IO;
using System.Collections;
using GlitchyEngine.Math;
using GlitchyEngine;
using GlitchyEngine.Renderer;

namespace Sandbox.VoxelFun
{
	public class World
	{
		public enum CreateError
		{
			case WorldAlreadyExists;
			case CreateDirectoryError(Platform.BfpFileResult error);
		}

		public enum LoadError
		{
			case WorldDoesNotExist;
			case DirectoryError(Platform.BfpFileResult error);
		}

		private int64 _seed;
		private String _name ~ delete _;
		private String _directory ~ delete _;

		private ChunkManager _chunkManager ~ delete _;

		public int64 Seed => _seed;
		public String Name => _name;
		public String Directory => _directory;

		public ChunkManager ChunkManager
		{
			get => _chunkManager;
			set => _chunkManager = value;
		}

		const String WorldsDirectory = "worlds";
		const String WorldFileName = "world.info";

		public static Result<void, CreateError> CreateWorld(String name, int64 seed, World outWorld)
		{
			String worldPath = new String();
			Path.InternalCombine(worldPath, WorldsDirectory, name);

			if(Directory.Exists(worldPath))
			{
				delete worldPath;
				return .Err(.WorldAlreadyExists);
			}

			if(Directory.CreateDirectory(worldPath) case .Err(let error))
			{
				delete worldPath;
				return .Err(.CreateDirectoryError(error));
			}

			String worldFilePath = Path.InternalCombine(.. scope .(), worldPath, WorldFileName);

			MemoryStream str = scope MemoryStream();
			str.Write(seed);

			Span<uint8> data = .(str.[Friend]mMemory.Ptr, str.Length);

			File.WriteAll(worldFilePath, data);

			outWorld._name = new String(name);
			outWorld._directory = worldPath;
			outWorld._seed = seed;

			return .Ok;
		}

		public static Result<void, LoadError> LoadWorld(String name, World outWorld)
		{
			String worldPath = new String();
			Path.InternalCombine(worldPath, WorldsDirectory, name);

			if(!Directory.Exists(worldPath))
				return .Err(.WorldDoesNotExist);

			String worldFilePath = Path.InternalCombine(.. scope .(), worldPath, WorldFileName);

			List<uint8> data = scope .();

			File.ReadAll(worldFilePath, data);

			int64 seed = *(int64*)data.Ptr;

			outWorld._name = new String(name);
			outWorld._directory = worldPath;
			outWorld._seed = seed;

			return .Ok;
		}

		/*
		public Point3 GetChunkCoordinate(Vector3 blockPosition)
		{
			Vector3 v = blockPosition / (Vector3)VoxelChunk.Size;

			Point3 p = .();
			p.X = (int)Math.Round(v.X);
			p.Y = (int)Math.Round(v.Y);
			p.Z = (int)Math.Round(v.Z);

			p.Y = 0;

			return p;
		}
		*/

		/**
		 * Returs the coordinate of the chunk that contains the given coordinate.
		 */
		public Vector3 GetChunkCoordinate(Vector3 blockCoordinate)
		{
			Vector3 chunkPosition = blockCoordinate / VoxelChunk.VectorSize;

			return Vector3.Floor(chunkPosition);
		}

		/**
		 * Calculates the coordinate of the chunk that contains the given block coordinate.
		 */
		public Point3 ChunkCoordFromBlockCoord(Point3 blockCoordinate)
		{
			Point3 coordinate = blockCoordinate;

			if(coordinate.X < 0)
				coordinate.X -= VoxelChunk.Size.X;

			if(coordinate.Y < 0)
				coordinate.Y -= VoxelChunk.Size.Y;
			
			if(coordinate.Z < 0)
				coordinate.Z -= VoxelChunk.Size.Z;

			return coordinate / VoxelChunk.Size;
		}
		
		/**
		 * Calculates the block coordinate relative to its chunk.
		 * For Example: Consider the block at the global location of (25, 17, -12)
		 * The coordinate of this block inside its chunk would be (9, 17, 4) because the chunk starts at (16, 0, -16)
		 */
		public Point3 BlockCoordInChunk(Point3 blockCoordinate)
		{
			Point3 chunkPosition = blockCoordinate % VoxelChunk.Size;

			if(chunkPosition.X < 0)
				chunkPosition.X += VoxelChunk.Size.X;

			if(chunkPosition.Y < 0)
				chunkPosition.Y += VoxelChunk.Size.Y;
			
			if(chunkPosition.Z < 0)
				chunkPosition.Z += VoxelChunk.Size.Z;

			return chunkPosition;
		}

		/**
		 * Returs the coordinate of the block relative to the chunk.
		 */
		public Vector3 GetPositionInChunk(Vector3 position)
		{
			Vector3 chunkPosition = position % VoxelChunk.VectorSize;

			if(chunkPosition.X < 0)
				chunkPosition.X += VoxelChunk.VectorSize.X;

			if(chunkPosition.Y < 0)
				chunkPosition.Y += VoxelChunk.VectorSize.Y;
			
			if(chunkPosition.Z < 0)
				chunkPosition.Z += VoxelChunk.VectorSize.Z;

			return Vector3.Floor(chunkPosition);
		}

		public Point3 RaycastBlock(Ray ray, float maxDistance, GeometryBinding geo, Effect effect)
		{
			Vector3 start = ray.Start;
			Vector3 dir = ray.Direction.Normalized();

			Vector3 unitStepSize = .((dir / dir.X).Magnitude(), (dir / dir.Y).Magnitude(), (dir / dir.Z).Magnitude());

			Point3 walker = (Point3)Vector3.Floor(start);

			Vector3 rayLengths = .();

			Point3 step;

			if(dir.X < 0)
			{
				step.X = -1;
				rayLengths.X = (start.X - (float)(walker.X)) * unitStepSize.X;
			}
			else
			{
				step.X = 1;
				rayLengths.X = ((float)(walker.X + 1) - start.X) * unitStepSize.X;
			}

			if(dir.Y < 0)
			{
				step.Y = -1;
				rayLengths.Y = (start.Y - (float)(walker.Y)) * unitStepSize.Y;
			}
			else
			{
				step.Y = 1;
				rayLengths.Y = ((float)(walker.Y + 1) - start.Y) * unitStepSize.Y;
			}
			
			if(dir.Z < 0)
			{
				step.Z = -1;
				rayLengths.Z = (start.Z - (float)(walker.Z)) * unitStepSize.Z;
			}
			else
			{
				step.Z = 1;
				rayLengths.Z = ((float)(walker.Z + 1) - start.Z) * unitStepSize.Z;
			}

			float distance = 0.0f;
			while(distance < maxDistance)
			{
				// Walk
				if(rayLengths.X < rayLengths.Y)
				{
					if(rayLengths.X < rayLengths.Z)
					{
						walker.X += step.X;
						distance = rayLengths.X;
						rayLengths.X += unitStepSize.X;
					}
					else
					{
						walker.Z += step.Z;
						distance = rayLengths.Z;
						rayLengths.Z += unitStepSize.Z;
					}
				}
				else
				{
					if(rayLengths.Y < rayLengths.Z)
					{
						walker.Y += step.Y;
						distance = rayLengths.Y;
						rayLengths.Y += unitStepSize.Y;
					}
					else
					{
						walker.Z += step.Z;
						distance = rayLengths.Z;
						rayLengths.Z += unitStepSize.Z;
					}
				}

				Point3 chunkCoordinate = ChunkCoordFromBlockCoord(walker);

				Chunk chunk = _chunkManager.LoadChunk(chunkCoordinate);

				Point3 coordInChunk = BlockCoordInChunk(walker);

				uint8 blockData = chunk.Data.Data[coordInChunk.X][coordInChunk.Y][coordInChunk.Z];

				if(blockData != 0)
				{
					return walker;
				}
				
			}

			return .(int.MaxValue, int.MaxValue, int.MaxValue);
		}
	}
}
