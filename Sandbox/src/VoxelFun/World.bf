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
		public Int32_3 GetChunkCoordinate(Vector3 blockPosition)
		{
			Vector3 v = blockPosition / (Vector3)VoxelChunk.Size;

			Int32_3 p = .();
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
		public static Vector3 GetChunkCoordinate(Vector3 blockCoordinate)
		{
			Vector3 chunkPosition = blockCoordinate / VoxelChunk.VectorSize;

			return Vector3.Floor(chunkPosition);
		}

		/**
		 * Calculates the coordinate of the chunk that contains the given block coordinate.
		 */
		public static Int32_3 ChunkCoordFromBlockCoord(Int32_3 blockCoordinate)
		{
			Int32_3 coordinate = blockCoordinate;

			if(coordinate.X < 0)
				coordinate.X -= VoxelChunk.Size.X - 1;

			if(coordinate.Y < 0)
				coordinate.Y -= VoxelChunk.Size.Y - 1;
			
			if(coordinate.Z < 0)
				coordinate.Z -= VoxelChunk.Size.Z - 1;

			return coordinate / VoxelChunk.Size;
		}
		
		/**
		 * Calculates the block coordinate relative to its chunk.
		 * For Example: Consider the block at the global location of (25, 17, -12)
		 * The coordinate of this block inside its chunk would be (9, 17, 4) because the chunk starts at (16, 0, -16)
		 */
		public static Int32_3 BlockCoordInChunk(Int32_3 blockCoordinate)
		{
			Int32_3 chunkPosition = blockCoordinate % VoxelChunk.Size;

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
		public static Vector3 GetPositionInChunk(Vector3 position)
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

		/*
		public struct BlockIntersection
		{
			Int32_3 BlockCoordinate;
		}
		*/
		public Int32_3 RaycastBlock(Ray ray, float maxDistance, GeometryBinding geo, Effect effect, out Vector3 intersectionPosition, out BlockFace intersectionFace)
		{
			Vector3 start = ray.Start;
			Vector3 dir = ray.Direction.Normalized();

			Vector3 unitStepSize = .((dir / dir.X).Magnitude(), (dir / dir.Y).Magnitude(), (dir / dir.Z).Magnitude());

			Int32_3 walker = (Int32_3)Vector3.Floor(start);

			Vector3 rayLengths = .();

			Int32_3 step;

			BlockFace xFace;
			BlockFace yFace;
			BlockFace zFace;

			if(dir.X < 0)
			{
				xFace = .Right;
				step.X = -1;
				rayLengths.X = (start.X - (float)(walker.X)) * unitStepSize.X;
			}
			else
			{
				xFace = .Left;
				step.X = 1;
				rayLengths.X = ((float)(walker.X + 1) - start.X) * unitStepSize.X;
			}

			if(dir.Y < 0)
			{
				yFace = .Top;
				step.Y = -1;
				rayLengths.Y = (start.Y - (float)(walker.Y)) * unitStepSize.Y;
			}
			else
			{
				yFace = .Bottom;
				step.Y = 1;
				rayLengths.Y = ((float)(walker.Y + 1) - start.Y) * unitStepSize.Y;
			}
			
			if(dir.Z < 0)
			{
				zFace = .Back;
				step.Z = -1;
				rayLengths.Z = (start.Z - (float)(walker.Z)) * unitStepSize.Z;
			}
			else
			{
				zFace = .Front;
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

						intersectionFace = xFace;
					}
					else
					{
						walker.Z += step.Z;
						distance = rayLengths.Z;
						rayLengths.Z += unitStepSize.Z;

						intersectionFace = zFace;
					}
				}
				else
				{
					if(rayLengths.Y < rayLengths.Z)
					{
						walker.Y += step.Y;
						distance = rayLengths.Y;
						rayLengths.Y += unitStepSize.Y;

						intersectionFace = yFace;
					}
					else
					{
						walker.Z += step.Z;
						distance = rayLengths.Z;
						rayLengths.Z += unitStepSize.Z;

						intersectionFace = zFace;
					}
				}

				Block blockData = [Inline]GetBlock(walker);

				if(blockData != Blocks.Air)
				{
					intersectionPosition = start + distance * dir;

					return walker;
				}
			}

			intersectionFace = .None;
			intersectionPosition = .(float.NaN);
			return .(int32.MaxValue, int32.MaxValue, int32.MaxValue);
		}

		/**
		 * Breaks the block at the given coordinates.
		 */
		public void BreakBlock(Int32_3 blockCoordinate)
		{
			Int32_3 chunkCoordinate = ChunkCoordFromBlockCoord(blockCoordinate);

			Chunk chunk = _chunkManager.LoadChunk(chunkCoordinate);

			Int32_3 coordInChunk = BlockCoordInChunk(blockCoordinate);

			Block block = chunk.GetBlock(coordInChunk);

			block.OnBreaking(blockCoordinate);

			chunk.SetBlock(coordInChunk, Blocks.Air);
		}

		/**
		 * Places a block at the given coordinates.
		 */
		public void PlaceBlock(Int32_3 blockCoordinate, Block block)
		{
			Int32_3 chunkCoordinate = ChunkCoordFromBlockCoord(blockCoordinate);

			Chunk chunk = _chunkManager.LoadChunk(chunkCoordinate);

			Int32_3 coordInChunk = BlockCoordInChunk(blockCoordinate);

			// Todo: we will also be able to place block in fluids and some other blocks.
			Log.ClientLogger.AssertDebug(chunk.GetBlock(coordInChunk) == Blocks.Air, "A block can only be placed in air (atm)");

			block.OnPlacing(blockCoordinate);

			chunk.SetBlock(coordInChunk, block);
		}

		/**
		 * Places a block on the given face of the block at the specified coordinates.
		 */
		public void PlaceBlock(Int32_3 blockCoordinate, Block block, BlockFace face)
		{
			var blockCoordinate;

			switch(face)
			{
			case .Front:
				blockCoordinate.Z--;
			case .Back:
				blockCoordinate.Z++;
			case .Left:
				blockCoordinate.X--;
			case .Right:
				blockCoordinate.X++;
			case .Bottom:
				blockCoordinate.Y--;
			case .Top:
				blockCoordinate.Y++;
			default:
				Log.ClientLogger.AssertDebug(false, "Unexpected block face.");
			}

			PlaceBlock(blockCoordinate, block);
		}

		/**
		 * Gets the block at the specified coordinate.
		 * @remarks If the blocks chunk is not loaded it will be loaded from the disk.
		 */
		public void SetBlock(Int32_3 blockCoordinate, Block block)
		{
			Int32_3 chunkCoordinate = ChunkCoordFromBlockCoord(blockCoordinate);

			Chunk chunk = _chunkManager.LoadChunk(chunkCoordinate);
			
			Int32_3 coordInChunk = BlockCoordInChunk(blockCoordinate);

			chunk.SetBlock(coordInChunk, block);
		}

		/**
		 * Gets the block at the specified coordinate.
		 * @remarks If the blocks chunk is not loaded it will be loaded from the disk.
		 */
		public Block GetBlock(Int32_3 blockCoordinate)
		{
			Int32_3 chunkCoordinate = ChunkCoordFromBlockCoord(blockCoordinate);

			Chunk chunk = _chunkManager.LoadChunk(chunkCoordinate);
			
			Int32_3 coordInChunk = BlockCoordInChunk(blockCoordinate);

			return chunk.GetBlock(coordInChunk);
		}

		[Test]
		static void TestWorld()
		{
			// ChunkCoordFromBlockCoord
			{
				Int32_3 block = .(0, 0, 0);
				Int32_3 expectedChunk = .(0, 0, 0);
				Test.Assert(expectedChunk == ChunkCoordFromBlockCoord(block));

				block = .(5, 0, 0);
				expectedChunk = .(0, 0, 0);
				Test.Assert(expectedChunk == ChunkCoordFromBlockCoord(block));

				block = .(45, 80, 12);
				expectedChunk = .(2, 0, 0);
				Test.Assert(expectedChunk == ChunkCoordFromBlockCoord(block));

				block = .(0, 0, -1);
				expectedChunk = .(0, 0, -1);
				Test.Assert(expectedChunk == ChunkCoordFromBlockCoord(block));
				
				block = .(0, 0, -16);
				expectedChunk = .(0, 0, -1);
				Test.Assert(expectedChunk == ChunkCoordFromBlockCoord(block));

				block = .(0, 0, -17);
				expectedChunk = .(0, 0, -2);
				Test.Assert(expectedChunk == ChunkCoordFromBlockCoord(block));
			}
		}
	}
}
