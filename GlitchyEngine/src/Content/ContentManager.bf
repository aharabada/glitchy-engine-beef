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
		/// @param contentManager The content manager used to load the asset.
		/// @returns The loaded asset.
		Asset LoadAsset(Stream file, AssetLoaderConfig config, StringView assetIdentifier, StringView? subAsset, IContentManager contentManager);

		/// Returns the placeholder asset.
		Asset GetPlaceholderAsset(Type assetType);

		/// Returns the error asset.
		Asset GetErrorAsset(Type assetType);
	}

	static class Content
	{
		/// Loads the specified asset with the given contentManager or the current applications content manager.
		public static AssetHandle LoadAsset(AssetHandle assetHandle, IContentManager contentManager = null, bool blocking = false)
		{
			var contentManager;

			if (contentManager == null)
				contentManager = Application.Get().ContentManager;

			AssetHandle handle = contentManager.LoadAsset(assetHandle, blocking);

			return handle;
		}

		/// Loads the specified asset with the given contentManager or the current applications content manager.
		public static AssetHandle LoadAsset(StringView assetIdentifier, IContentManager contentManager = null, bool blocking = false)
		{
			var contentManager;

			if (contentManager == null)
				contentManager = Application.Get().ContentManager;

			AssetHandle handle = contentManager.LoadAsset(assetIdentifier, blocking);

			return handle;
		}

		/// Loads the specified asset with the given contentManager or the current applications content manager.
		public static T GetAsset<T>(AssetHandle handle, IContentManager contentManager = null) where T : Asset
		{
			var contentManager;

			if (contentManager == null)
				contentManager = Application.Get().ContentManager;

			Asset asset = contentManager.GetAsset(typeof(T), handle);

			return (T)asset;
		}

		/// Loads the specified asset with the given contentManager or the current applications content manager.
		public static Asset GetAsset(AssetHandle handle, IContentManager contentManager = null)
		{
			var contentManager;

			if (contentManager == null)
				contentManager = Application.Instance.ContentManager;

			Asset asset = contentManager.GetAsset(null, handle);

			return asset;
		}
		
		public static AssetHandle ManageAsset(Asset asset, IContentManager contentManager = null)
		{
			var contentManager;

			if (contentManager == null)
				contentManager = Application.Get().ContentManager;

			return contentManager.ManageAsset(asset);
		}

		/*public static AssetHandle<T> ManageAsset<T>(T asset, IContentManager contentManager = null) where T : Asset
		{
			var contentManager;

			if (contentManager == null)
				contentManager = Application.Get().ContentManager;

			contentManager.ManageAsset(asset);
		}*/
	}

	interface IContentManager
	{
		/// Loads the Asset with the given handle and returns the handle.
		AssetHandle LoadAsset(StringView assetIdentifier, bool blocking = false);

		/// Loads the Asset with the given handle and returns the handle. Returns .Invalid, if the asset handle doesn't exist.
		AssetHandle LoadAsset(AssetHandle handle, bool blocking = false);

		/// Returns the asset for the given handle or null, if it isn't loaded.
		Asset GetAsset(AssetHandle handle)
		{
			return GetAsset(null, handle);
		}

		/// Returns the asset for the given handle or the default asset of the given type.
		Asset GetAsset(Type assetType, AssetHandle handle);

		/// The content manager will manage the asset (e.g. provide it when LoadAsset is called with the assets identifier)
		AssetHandle ManageAsset(Asset asset);

		/// The content manager will no longer manage the asset.
		void UnmanageAsset(AssetHandle asset);

		/// Returns a data stream for the given asset.
		Stream GetStream(StringView assetIdentifier, bool openOnly = true);

		void RegisterAssetLoader<T>() where T : new, class, IAssetLoader;
		void SetAsDefaultAssetLoader<T>(params Span<StringView> fileExtensions) where T : IAssetLoader;
		//void GetFilePath(String outFilename, String filename);

		//Stream GetFile(String filename);
	}
}