using System;
using System.IO;
using xxHash;
using System.Collections;
using Bon;

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
	
	[BonTarget, BonPolyRegister]
	abstract class AssetLoaderConfig
	{
	    [BonIgnore]
		protected bool _changed;

		public bool Changed => _changed;

		protected bool SetIfChanged<T>(ref T field, T value)
		{
			if (field == value)
				return false;

			field = value;
			_changed = true;

			return true;
		}
	}

	interface IAssetLoader
	{
		static List<StringView> FileExtensions { get; }

		AssetLoaderConfig GetDefaultConfig();

		/// Loads the asset from the given data stream with the specified config.
		/// @param file The stream containing the asset.
		/// @param config The configuration which specifies the settings used to load the asset.
		/// @returns The loaded asset.
		IRefCounted LoadAsset(Stream file, AssetLoaderConfig config);
	}

	static
	{
		/// Loads the specified asset with the given contentManager or the current applications content manager.
		public static T LoadAsset<T>(StringView assetIdentifier, IContentManager contentManager = null) where T : IRefCounted
		{
			var contentManager;

			if (contentManager == null)
				contentManager = Application.Get().ContentManager;

			Object o = contentManager.LoadAsset(assetIdentifier);

			Log.EngineLogger.AssertDebug(o is T);

			return (T)o;
		}
	}

	interface IContentManager
	{
		/// Loads the given asset.
		IRefCounted LoadAsset(StringView assetIdentifier);

		/// Returns a data stream for the given asset.
		Stream GetStream(StringView assetIdentifier);

		void RegisterAssetLoader<T>() where T : new, class, IAssetLoader;
		void SetAsDefaultAssetLoader<T>(params StringView[] fileExtensions) where T : IAssetLoader;
		//void GetFilePath(String outFilename, String filename);

		//Stream GetFile(String filename);
	}

	class RuntimeContentManager : IContentManager
	{
		public IRefCounted LoadAsset(StringView identifier)
		{
			Runtime.NotImplemented();
		}

		public Stream GetStream(StringView assetIdentifier)
		{
			Runtime.NotImplemented();
		}

		public void RegisterAssetLoader<T>() where T : IAssetLoader where T : class where T : new
		{
			Runtime.NotImplemented();
		}

		public void SetAsDefaultAssetLoader<T>(params StringView[] fileExtensions) where T : IAssetLoader
		{
			Runtime.NotImplemented();
		}
		/*private String _contentRoot;

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

			Log.EngineLogger.AssertDebug(File.Exists(fullpath), "File doesn't exist!");

			FileStream stream = new FileStream();
			var result = stream.Open(fullpath, .Read, .Read);

			if (result case .Err(let error))
			{
				Log.EngineLogger.Error($"Failed to open file \"{fullpath}\". Error: {error}");
				return null;
			}

			return stream;
		}*/
	}
}