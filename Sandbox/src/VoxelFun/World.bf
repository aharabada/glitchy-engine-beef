using System;
using System.IO;
using System.Collections;
using GlitchyEngine.Math;
using GlitchyEngine;

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

		public Point3 GetChunkCoordinate(Point3 blockCoordinate)
		{
			Point3 p = blockCoordinate;
			if(p.X < 0)
				p.X -= VoxelChunk.Size.X;
			if(p.Y < 0)
				p.Y -= VoxelChunk.Size.Y;
			if(p.Z < 0)
				p.Z -= VoxelChunk.Size.Z;

			return .(p.X / VoxelChunk.Size.X, 0, p.Z / VoxelChunk.Size.Z);//p.Y / VoxelChunk.Size.Y
		}

		public Point3 RaycastBlock(Ray ray, float maxDistance)
		{
			Vector3 rayWalker = ray.Start;
			Vector3 direction = ray.Direction.Normalized();

			for(float walkedLength = 0; walkedLength < maxDistance; rayWalker += direction, walkedLength++)
			{
				Point3 blockCoordinate = (.)rayWalker;

				Point3 chunkCoordinate = GetChunkCoordinate(blockCoordinate);

				Chunk chunk = _chunkManager.LoadChunk(chunkCoordinate);

				Point3 coordInChunk = blockCoordinate - chunkCoordinate * VoxelChunk.Size;

				int blockData = chunk.Data.Data[coordInChunk.X][coordInChunk.Y][coordInChunk.Z];

				if(blockData != 0)
					return blockCoordinate;

				//Point3 chunkCoordinate = GetChunkCoordinate(rayWalker);
				
				//Chunk chunk = _chunkManager.LoadChunk(chunkCoordinate);

				//Point3 blockIndex = (Point3)rayWalker - chunkCoordinate * VoxelChunk.Size;

				//int blockData = chunk.Data.Data[blockIndex.X][blockIndex.Y][blockIndex.Z];

				//if(blockData != 0)
				//	return blockIndex;
			}

			return .(int.MaxValue, int.MaxValue, int.MaxValue);
		}
	}
}
