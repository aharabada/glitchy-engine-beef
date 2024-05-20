using System.Interop;
using System;
using static System.Windows;

namespace LZ4;

[CRepr]
enum LZ4F_ErrorCode : c_size
{
	OK_NoError,
	ERROR_GENERIC,
	ERROR_maxBlockSize_invalid,
	ERROR_blockMode_invalid,
	ERROR_parameter_invalid,
	ERROR_compressionLevel_invalid,
	ERROR_headerVersion_wrong,
	ERROR_blockChecksum_invalid,
	ERROR_reservedFlag_set,
	ERROR_allocation_failed,
	ERROR_srcSize_tooLarge,
	ERROR_dstMaxSize_tooSmall,
	ERROR_frameHeader_incomplete,
	ERROR_frameType_unknown,
	ERROR_frameSize_wrong,
	ERROR_srcPtr_wrong,
	ERROR_decompressionFailed,
	ERROR_headerChecksum_invalid,
	ERROR_contentChecksum_invalid,
	ERROR_frameDecoding_alreadyStarted,
	ERROR_compressionState_uninitialized,
	ERROR_parameter_null,
	ERROR_io_write,
	ERROR_io_read,
	ERROR_maxCode
}

[CRepr]
enum LZ4F_BlockSizeID : uint32
{
	Default=0,
	Max64KB=4,
	Max256KB=5,
	Max1MB=6,
	Max4MB=7
}

[CRepr]
enum LZ4F_BlockMode : uint32
{
	Linked = 0,
	Independent
}

[CRepr]
enum LZ4F_ContentChecksum : uint32
{
	NoContentChecksum = 0,
	ContentChecksumEnabled
}

[CRepr]
enum LZ4F_BlockChecksum : uint32
{
	NoBlockChecksum = 0,
	BlockChecksumEnabled
}

[CRepr]
enum LZ4F_FrameType : uint32
{
	Frame = 0,
	SkippableFrame
}

[CRepr]
struct LZ4F_FrameInfo
{
	public LZ4F_BlockSizeID BlockSizeID;
	public LZ4F_BlockMode BlockMode;
	public LZ4F_ContentChecksum ContentChecksumFlag;
	public LZ4F_FrameType FrameType;
	public c_ulonglong ContentSize;
	public c_uint DictID;
	public LZ4F_BlockChecksum BlockChecksumFlag;

	public this(LZ4F_BlockSizeID blockSizeID = .Max64KB, LZ4F_BlockMode blockMode = .Linked,
		LZ4F_ContentChecksum contentChecksumFlag = .NoContentChecksum,
		LZ4F_FrameType frameType = .Frame, c_ulonglong contentSize = 0, c_uint dictID = 0,
		LZ4F_BlockChecksum blockChecksumFlag = .NoBlockChecksum)
	{
		BlockSizeID = blockSizeID;
		BlockMode = blockMode;
		ContentChecksumFlag = contentChecksumFlag;
		FrameType = frameType;
		ContentSize = contentSize;
		DictID = dictID;
		BlockChecksumFlag = blockChecksumFlag;
	}
}

[CRepr]
struct LZ4F_Preferences
{
	public LZ4F_FrameInfo FrameInfo;
	public c_int CompressionLevel;
	public IntBool AutoFlush;
	public IntBool FavorDecSpeed;
	private c_uint[3] Reserved;

	public this(LZ4F_FrameInfo frameInfo = .(), c_int compressionLevel = 0, bool autoFlush = false,
		bool favorDecSpeed = false)
	{
		FrameInfo = frameInfo;
		CompressionLevel = compressionLevel;
		AutoFlush = autoFlush;
		FavorDecSpeed = favorDecSpeed;
		Reserved = default;
	}
}

struct LZ4F_dctx;

static
{
	[LinkName("LZ4F_isError")]
	public static extern c_int LZ4F_IsError(LZ4F_ErrorCode code);

	[LinkName("LZ4F_getErrorName")]
	public static extern char8* LZ4F_GetErrorName(LZ4F_ErrorCode code);

	// Simple Compression

	[LinkName("LZ4F_compressFrame")]
	public static extern c_size LZ4F_CompressFrame(void* dstBuffer, c_size dstCapacity,
                                void* srcBuffer, c_size srcSize,
                                LZ4F_Preferences* preferencesPtr = null);

	public static c_size LZ4F_CompressFrame(Span<uint8> dstBuffer,
                                Span<uint8> srcBuffer,
                                LZ4F_Preferences* preferencesPtr = null)
	{
#unwarn
		return LZ4F_CompressFrame(dstBuffer.Ptr, (c_size)dstBuffer.Length, srcBuffer.Ptr, (c_size)srcBuffer.Length, preferencesPtr);
	}
	
	[LinkName("LZ4F_compressFrameBound")]
	public static extern c_size LZ4F_CompressFrameBound(c_size srcSize, LZ4F_Preferences* preferencesPtr = null);

	[LinkName("LZ4F_compressionLevel_max")]
	public static extern c_int LZ4F_CompressionLevel_Max();

	// Decompression
	
	[LinkName("LZ4F_createDecompressionContext")]
	public static extern LZ4F_ErrorCode LZ4F_CreateDecompressionContext(LZ4F_dctx** dctxPtr, c_uint version);

	public const c_uint LZ4F_VERSION = 100;

	public static LZ4F_ErrorCode LZ4F_CreateDecompressionContext(out LZ4F_dctx* dctxPtr, c_uint version = LZ4F_VERSION)
	{
		dctxPtr = ?;
		return LZ4F_CreateDecompressionContext(&dctxPtr, LZ4F_VERSION);
	}

	[LinkName("LZ4F_freeDecompressionContext")]
	public static extern LZ4F_ErrorCode LZ4F_FreeDecompressionContext(LZ4F_dctx* dctx);

	[LinkName("LZ4F_decompress")]
	public static extern c_size LZ4F_Decompress(LZ4F_dctx* dctx,
		                void* dstBuffer, c_size* dstSizePtr,
		          		void* srcBuffer, c_size* srcSizePtr,
		          		void* dOptPtr);

	public static c_size LZ4F_Decompress(LZ4F_dctx* dctx,
		                Span<uint8> dstBuffer,
		          		Span<uint8> srcBuffer, out c_size bytesRead, out c_size bytesWritten,
		          		void* dOptPtr = null)
	{
		bytesRead = (c_size)srcBuffer.Length;
		bytesWritten = (c_size)dstBuffer.Length;

		return LZ4F_Decompress(dctx, dstBuffer.Ptr, &bytesWritten, srcBuffer.Ptr, &bytesRead, dOptPtr);
	}
}