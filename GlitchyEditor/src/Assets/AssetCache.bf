using System;
using GlitchyEngine;
using System.IO;
using System.Collections;
using GlitchyEngine.Core;
using GlitchyEngine.Content;
using System.IO;

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
	public AssetIdentifier AssetIdentifier ~ delete _;

	public int32 DataOffset;

	public const String CacheFileExtension = ".laf";
}

/// Manages the cache for already processed assets
class AssetCache
{
	/// Current format version of loose asset file (.laf) file reader and writer.
	public const uint16 FormatVersion = 1;

	private append String _projectCacheDirectory = .();// ~ delete:append _;
	private append String _globalCacheDirectory = .();// ~ delete:append _;

	private append Dictionary<AssetHandle, CachedAsset> _assets = .();// ~ delete:append _;

	public StringView ProjectCacheDirectory => _projectCacheDirectory;
	public StringView GlobalCacheDirectory => _globalCacheDirectory;

	private bool _cacheLoaded;

	private EditorContentManager _contentManager;

	public this(EditorContentManager contentManager)
	{
		_contentManager = contentManager;
	}

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
	public void SetGlobalCacheDirectory(StringView directory)
	{
		_globalCacheDirectory.Set(directory);
		ReloadCache();
	}

	/// Sets the directory in which the processed assets are cached.
	public void SetProjectCacheDirectory(StringView directory)
	{
		_projectCacheDirectory.Set(directory);
		ReloadCache();
	}

	// TODO: This might take ages for large projects and definitely shouldn't run in the main thread!
	public void ReloadCache()
	{
		ClearCache();

		LoadCache(_globalCacheDirectory);
		LoadCache(_projectCacheDirectory);

		_cacheLoaded = true;
	}

	private void LoadCache(StringView directory)
	{
		if (directory.IsWhiteSpace)
			return;

		if (!Directory.Exists(directory))
		{
			Log.EngineLogger.Info($"Asset cache directory doesn't exist, creating directory \"{directory}\"...");

			if (Directory.CreateDirectory(directory) case .Err(let error))
			{
				Log.EngineLogger.Critical($"Failed to create cache directory \"{directory}\". Reason: {error}.");
				Log.EngineLogger.Critical($"The engine will not function properly without the asset cache directory. Save your project and restart the engine.");
			}

			// At this point we either just created the cache directory and thus it's empty,
			// or we failed and can't do anything anyway.
			return;
		}

		String filePath = scope .();
		for (FileFindEntry file in Directory.EnumerateFiles(directory))
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
				continue;
			}

			_assets.Add(cachedAsset.Handle, cachedAsset);
		}
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

		int16 assetIdentifierByteCount = Try!(stream.Read<int16>());

		String assetIdentifier = scope String(assetIdentifierByteCount);
		assetIdentifier.PadLeft(assetIdentifierByteCount);
		Span<char8> charSpan = assetIdentifier;
		int readBytes = Try!(stream.TryRead(Span<uint8>((uint8*)charSpan.Ptr, charSpan.Length)));

		cachedAsset.AssetIdentifier = new AssetIdentifier(assetIdentifier);

		if (readBytes != assetIdentifierByteCount)
		{
			Log.EngineLogger.Warning($"Expected to read {assetIdentifierByteCount} bytes for the asset identifier, but read {readBytes} instead.");
		}

		cachedAsset.DataOffset = (.)stream.Position;

		return .Ok;
	}

	public CachedAsset GetCacheEntry(AssetHandle assetHandle)
	{
		if (!_cacheLoaded)
			ReloadCache();

		if (_assets.TryGetValue(assetHandle, let cachedAsset))
			return cachedAsset;

		return null;
	}

	private void GetProjectCacheFilePath(AssetHandle handle, String outFilePath)
	{
		outFilePath.Append(_projectCacheDirectory);
		outFilePath.Append(Path.DirectorySeparatorChar);
		outFilePath.Append(handle);
		outFilePath.Append(CachedAsset.CacheFileExtension);
	}

	private void GetGlobalCacheFilePath(AssetHandle handle, String outFilePath)
	{
		outFilePath.Append(_globalCacheDirectory);
		outFilePath.Append(Path.DirectorySeparatorChar);
		outFilePath.Append(handle);
		outFilePath.Append(CachedAsset.CacheFileExtension);
	}

	public Result<void> SaveAsset(CachedAsset assetInfo, Span<uint8> data)
	{
		CachedAsset asset = GetCacheEntry(assetInfo.Handle);

		if (asset == null)
		{
			asset = new CachedAsset();
			asset.Handle = assetInfo.Handle;
			asset.FilePath = new String(128);

			if (assetInfo.AssetIdentifier.IsResource)
				GetGlobalCacheFilePath(asset.Handle, asset.FilePath);
			else
				GetProjectCacheFilePath(asset.Handle, asset.FilePath);

			_assets[asset.Handle] = asset;
		}

		delete asset.AssetIdentifier;
		asset.AssetIdentifier = new AssetIdentifier(assetInfo.AssetIdentifier);

		asset.FormatVersion = FormatVersion;
		asset.Compression = assetInfo.Compression;
		asset.AssetType = assetInfo.AssetType;
		asset.CreationTimestamp = assetInfo.CreationTimestamp;

		asset.UncompressedByteCount = data.Length;

		Span<uint8> dataToWrite;

		switch (asset.Compression)
		{
		case .LZ4:
			uint maxCompressedSize = LZ4.LZ4F_CompressFrameBound((uint)data.Length);

			uint8[] compressedData = new uint8[maxCompressedSize];
			defer { delete compressedData; }

			uint actualCompressedSize = LZ4.LZ4F_CompressFrame(compressedData, data);

			asset.CompressedByteCount = (int)actualCompressedSize;

			dataToWrite = Span<uint8>(compressedData.Ptr, (int)actualCompressedSize);
		case .None:
			asset.CompressedByteCount = data.Length;
			dataToWrite = data;
		}

		FileStream writer = scope .();
		Try!(writer.Create(asset.FilePath, .Write, .None));

		Try!(writer.Write<char8[3]>(CachedAsset.MagicWord));
		Try!(writer.Write(FormatVersion));
		Try!(writer.Write(asset.Handle));
		Try!(writer.Write(asset.CreationTimestamp));
		Try!(writer.Write(asset.Compression));
		Try!(writer.Write(asset.AssetType));
		Try!(writer.Write<int64>(asset.CompressedByteCount));
		Try!(writer.Write<int64>(asset.UncompressedByteCount));

		Try!(writer.Write<int16>((int16)asset.AssetIdentifier.FullIdentifier.Length));
		Try!(writer.Write(asset.AssetIdentifier.FullIdentifier));
		
		asset.DataOffset = (.)writer.Position;

		Try!(writer.Write(dataToWrite));

		_contentManager.QueueAssetReload(asset.Handle);

		return .Ok;
	}

	private Result<void> OpenFileStream(CachedAsset asset, FileStream fileStream)
	{
		if (asset == null)
			return .Err;

		Try!(fileStream.Close());
		Try!(fileStream.Open(asset.FilePath, .Read, .Read));

		fileStream.Position = asset.DataOffset;

		return .Ok;
	}

	public Result<Stream> OpenStream(CachedAsset asset)
	{
		if (asset == null)
			return .Err;

		switch (asset.Compression)
		{
		case .None:
			FileStream fileStream = new FileStream();
			Try!(OpenFileStream(asset, fileStream));
			return fileStream;
		case .LZ4:
			FileStream compressedStream = scope FileStream();
			Try!(OpenFileStream(asset, compressedStream));

			uint8[] compressedData = new uint8[asset.CompressedByteCount];
			defer { delete compressedData; }

			Try!(compressedStream.TryRead(compressedData));

			MemoryStream ms = new MemoryStream(asset.UncompressedByteCount);
			ms.Memory.GrowUnitialized(asset.UncompressedByteCount);

			LZ4.LZ4F_dctx* context;
			LZ4.LZ4F_CreateDecompressionContext(out context);

			while (true)
			{
				var result = LZ4.LZ4F_Decompress(context, ms.Memory, compressedData,let bytesRead, let bytesWritten);
				if (result == 0)
					break;
			}

			LZ4.LZ4F_FreeDecompressionContext(context);

			ms.Position = 0;

			return ms;
		}
	}
}