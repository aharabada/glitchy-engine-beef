using System;
using System.IO;
using System.Collections;

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

		public int64 Seed => _seed;
		public String Name => _name;
		public String Directory => _directory;

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
	}
}
