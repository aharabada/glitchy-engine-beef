using System;
using System.IO;
using xxHash;

namespace GlitchyEngine.Content
{
	class ContentId
	{
		private readonly String _string;
		private readonly XXH64_hash _hash;

		public String String => _string;
		public XXH64_hash Hash => _hash;

		[AllowAppend]
		public this(StringView id)
		{
			String str = append String(id);

		    _string = str;

		    _hash = xxHash.ComputeHash(id);
		}
	}

	interface IContentManager
	{
		void GetFilePath(String outFilename, String filename);

		Stream GetFile(String filename);
	}

	class ContentManager : IContentManager
	{
		private String _contentRoot;

		[AllowAppend]
		public this(String contentRoot)
		{
			String cntRoot = append String(contentRoot);
			_contentRoot = cntRoot;

			Runtime.Assert(Directory.Exists(contentRoot), "Content root directory doesn't exist.");
		}

		public void GetFilePath(String outFilename, String filename)
		{
			Path.InternalCombine(outFilename, _contentRoot, filename);
		}

		public Stream GetFile(String filename)
		{
			String fullpath = scope .(_contentRoot.Length + 1 + filename.Length);
			GetFilePath(fullpath, filename);

			FileStream stream = new FileStream();
			var result = stream.Open(fullpath, .Read, .Read);

			if (result case .Err(let error))
			{
				Log.EngineLogger.Error($"Failed to open file \"{fullpath}\". Error: {error}");
				return null;
			}

			return stream;
		}
	}
}