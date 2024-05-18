using System;
using GlitchyEngine;
using System.IO;
using System.Collections;
using GlitchyEngine.Core;
using GlitchyEngine.Content;

namespace GlitchyEditor.Assets;

/// Represents a processed asset file as it lies in the cache-directory.
class CachedAsset
{
	public const char8[3] MagicWord = .('L', 'A', 'F');
	
	public String FilePath ~ delete _;

	public uint16 FormatVersion;
	public AssetHandle Handle;
	public DateTime CreationTimestamp;
	public AssetCompression Compression;
	public AssetType AssetType;
	public int64 CompressedByteCount;
	public int64 UncompressedByteCount;
	public String AssetIdentifier ~ delete _;

	public const String CacheFileExtension = ".laf";
}

/// Manages the cache for already processed assets
class AssetCache
{
	/// Current format version of loose asset file (.laf) file reader and writer.
	public const uint16 FormatVersion = 1;

	private append String _directory = .() ~ delete:append _;

	private append Dictionary<AssetHandle, CachedAsset> _assets ~ delete:append _;

	public StringView CacheDirectory => _directory;

	private bool _cacheLoaded;

	public ~this()
	{
		ClearCache();
	}

	private void ClearCache()
	{
		_cacheLoaded = false;
		ClearDictionaryAndDeleteValues!(_assets);
	}

	/// Sets the directory in which the processed assets are cached.
	public void SetDirectory(StringView directory)
	{
		_directory.Set(directory);
		ReloadCache();
	}

	// TODO: This might take ages for large projects and definitely shouldn't run in the main thread!
	public void ReloadCache()
	{
		ClearCache();

		if (!Directory.Exists(_directory))
		{
			Log.EngineLogger.Info($"Asset cache directory doesn't exist, creating directory \"{_directory}\"...");

			if (Directory.CreateDirectory(_directory) case .Err(let error))
			{
				Log.EngineLogger.Critical($"Failed to create cache directory \"{_directory}\". Reason: {error}.");
				Log.EngineLogger.Critical($"The engine will not function properly without the asset cache directory. Save your project and restart the engine.");
			}

			// At this point we either just created the cache directory and thus it's empty,
			// or we failed and can't do anything anyway.
			return;
		}
		
		String filePath = scope .();
		for (FileFindEntry file in Directory.EnumerateFiles(_directory))
		{
			filePath.Clear();
			file.GetFilePath(filePath);

			if (!filePath.EndsWith(CachedAsset.CacheFileExtension, .OrdinalIgnoreCase))
				continue;
			
			CachedAsset cachedAsset = new .();
			if (ReadAssetFile(filePath, cachedAsset) case .Err)
			{
				Log.EngineLogger.Error($"Failed to read cached asset file \"filePath\".");

				delete cachedAsset;
			}

			_assets.Add(cachedAsset.Handle, cachedAsset);
		}

		_cacheLoaded = true;
	}

	private Result<void> ReadAssetFile(StringView filePath, CachedAsset cachedAsset)
	{
		cachedAsset.FilePath = new String(filePath);

		FileStream stream = scope .();
		Try!(stream.Open(filePath));

		// Check magic word
		char8[3] magicWord = Try!(stream.Read<char8[3]>());
		if (magicWord != CachedAsset.MagicWord)
			return .Err;

		cachedAsset.FormatVersion = Try!(stream.Read<uint16>());

		// Validate format version
		if (cachedAsset.FormatVersion == 0 || cachedAsset.FormatVersion > FormatVersion)
		{
			Log.EngineLogger.Error("The cached assets version is either invalid or too new.");
			return .Err;
		}

		cachedAsset.Handle = Try!(stream.Read<AssetHandle>());
		cachedAsset.CreationTimestamp = Try!(stream.Read<DateTime>());
		cachedAsset.Compression = Try!(stream.Read<AssetCompression>());
		cachedAsset.AssetType = Try!(stream.Read<AssetType>());
		cachedAsset.CompressedByteCount = Try!(stream.Read<int64>());
		cachedAsset.UncompressedByteCount = Try!(stream.Read<int64>());

		int32 assetIdentifierByteCount = Try!(stream.Read<int32>());

		cachedAsset.AssetIdentifier = new String(assetIdentifierByteCount);
		cachedAsset.AssetIdentifier.PadLeft(assetIdentifierByteCount);
		Span<char8> charSpan = cachedAsset.AssetIdentifier;
		int readBytes = Try!(stream.TryRead(Span<uint8>((uint8*)charSpan.Ptr, charSpan.Length)));

		if (readBytes != assetIdentifierByteCount)
		{
			Log.EngineLogger.Warning($"Expected to read {assetIdentifierByteCount} bytes for the asset identifier, but read {readBytes} instead.");
		}

		return .Ok;
	}

	public CachedAsset GetCacheEntry(AssetHandle id)
	{
		if (!_cacheLoaded)
			ReloadCache();

		if (_assets.TryGetValue(id, let cachedAsset))
			return cachedAsset;

		return null;
	}
}