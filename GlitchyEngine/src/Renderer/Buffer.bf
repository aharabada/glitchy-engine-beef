using System;
using GlitchyEngine.Core;

namespace DirectX.DXGI
{
	public extension Format
	{
		public bool IsInt()
		{
			switch(this)
			{
			case R32G32B32A32_SInt, R32G32B32_SInt, R16G16B16A16_SInt, R32G32_SInt, R8G8B8A8_SInt, R16G16_SInt,
				 R32_SInt, R8G8_SInt, R16_SInt, R8_SInt:
				return true;
			default:
				return false;
			}
		}

		public bool IsUInt()
		{
			switch(this)
			{
			case R32G32B32A32_UInt, R32G32B32_UInt, R16G16B16A16_UInt, R32G32_UInt, R10G10B10A2_UInt, R8G8B8A8_UInt, R16G16_UInt,
				 R32_UInt, R8G8_UInt, R16_UInt, R8_UInt:
				return true;
			default:
				return false;
			}
		}

		public uint32 BitsPerPixel()
		{
			switch (this)
			{
			case .R32G32B32A32_Typeless,.R32G32B32A32_Float,.R32G32B32A32_UInt,.R32G32B32A32_SInt:
				return 128;

			case .R32G32B32_Typeless,.R32G32B32_Float,.R32G32B32_UInt,.R32G32B32_SInt:
				return 96;

			case .R16G16B16A16_Typeless,.R16G16B16A16_Float,.R16G16B16A16_UNorm,.R16G16B16A16_UInt,.R16G16B16A16_SNorm,.R16G16B16A16_SInt,.R32G32_Typeless,.R32G32_Float,.R32G32_UInt,.R32G32_SInt,.R32G8X24_Typeless,.D32_Float_S8X24_UInt,.R32_Float_X8X24_Typeless,.X32_Typeless_G8X24_UInt,.Y416,.Y210,.Y216:
				return 64;

			case .R10G10B10A2_Typeless,.R10G10B10A2_UNorm,.R10G10B10A2_UInt,.R11G11B10_Float,.R8G8B8A8_Typeless,.R8G8B8A8_UNorm,.R8G8B8A8_UNorm_SRGB,.R8G8B8A8_UInt,.R8G8B8A8_SNorm,.R8G8B8A8_SInt,.R16G16_Typeless,.R16G16_Float,.R16G16_UNorm,.R16G16_UInt,.R16G16_SNorm,.R16G16_SInt,.R32_Typeless,.D32_Float,.R32_Float,.R32_UInt,.R32_SInt,.R24G8_Typeless,.D24_UNorm_S8_UInt,.R24_UNorm_X8_Typeless,.X24_Typeless_G8_UInt,.R9G9B9E5_SHAREDEXP,.R8G8_B8G8_UNorm,.G8R8_G8B8_UNorm,.B8G8R8A8_UNorm,.B8G8R8X8_UNorm,.R10G10B10_XR_BIAS_A2_UNorm,.B8G8R8A8_Typeless,.B8G8R8A8_UNorm_SRGB,.B8G8R8X8_Typeless,.B8G8R8X8_UNorm_SRGB,.AYUV,.Y410,.YUY2:
			//#if (defined(_XBOX_ONE) && defined(_TITLE)) || defined(_GAMING_XBOX)
			//case .R10G10B10_7E3_A2_Float,.R10G10B10_6E4_A2_Float,.R10G10B10_SNorm_A2_UNorm:
			//#endif
				return 32;

			case .P010,.P016, .V408:
			/*#if (_WIN32_WINNT >= _WIN32_WINNT_WIN10)
			case .V408:
			#endif
			#if (defined(_XBOX_ONE) && defined(_TITLE)) || defined(_GAMING_XBOX)
			case .D16_UNorm_S8_UInt,.R16_UNorm_X8_Typeless,.X16_Typeless_G8_UInt:
			#endif*/
				return 24;

			case .R8G8_Typeless,.R8G8_UNorm,.R8G8_UInt,.R8G8_SNorm,.R8G8_SInt,.R16_Typeless,.R16_Float,.D16_UNorm,.R16_UNorm,.R16_UInt,.R16_SNorm,.R16_SInt,.B5G6R5_UNorm,.B5G5R5A1_UNorm,.A8P8,.B4G4R4A4_UNORM, .P208,.V208:
			/*#if (_WIN32_WINNT >= _WIN32_WINNT_WIN10)
			case .P208,.V208:
			#endif*/
				return 16;

			case .NV12,.OPAQUE_420,.NV11:
				return 12;

			case .R8_Typeless,.R8_UNorm,.R8_UInt,.R8_SNorm,.R8_SInt,.A8_UNorm,.BC2_Typeless,.BC2_UNorm,.BC2_UNorm_SRGB,.BC3_Typeless,.BC3_UNorm,.BC3_UNorm_SRGB,.BC5_Typeless,.BC5_UNorm,.BC5_SNorm,.BC6H_Typeless,.BC6H_UF16,.BC6H_SF16,.BC7_Typeless,.BC7_UNorm,.BC7_UNorm_SRGB,.AI44,.IA44,.P8:
			/*#if (defined(_XBOX_ONE) && defined(_TITLE)) || defined(_GAMING_XBOX)
			case .R4G4_UNorm:
			#endif*/
				return 8;

			case .R1_UNorm:
				return 1;

			case .BC1_Typeless,.BC1_UNorm,.BC1_UNorm_SRGB,.BC4_Typeless,.BC4_UNorm,.BC4_SNorm:
				return 4;

			//case .Unknown,.FORCE_UInt:
			default:
				return 0;
			}
		}

		/// Returns the SRGB-Format for the given Format, or the Format itself, if no SRGB-variant exists.
		public Format GetSRGB()
		{
			switch (this)
			{
			case .BC1_UNorm:
				return .BC1_UNorm_SRGB;
			case .BC2_UNorm:
					return .BC2_UNorm_SRGB;
			case .BC3_UNorm:
					return .BC3_UNorm_SRGB;
			case .BC7_UNorm:
					return .BC7_UNorm_SRGB;
			case .R8G8B8A8_UNorm:
					return .R8G8B8A8_UNorm_SRGB;
			case .B8G8R8A8_UNorm:
					return .B8G8R8A8_UNorm_SRGB;
			case .B8G8R8X8_UNorm:
					return .B8G8R8X8_UNorm_SRGB;
			default:
				return this;
			}
		}
		
		/// Returns the non-SRGB-Format for the given Format.
		public Format GetNonSRGB()
		{
			switch (this)
			{
			case .BC1_UNorm_SRGB:
				return .BC1_UNorm;
			case .BC2_UNorm_SRGB:
					return .BC2_UNorm;
			case .BC3_UNorm_SRGB:
					return .BC3_UNorm;
			case .BC7_UNorm_SRGB:
					return .BC7_UNorm;
			case .R8G8B8A8_UNorm_SRGB:
					return .R8G8B8A8_UNorm;
			case .B8G8R8A8_UNorm_SRGB:
					return .B8G8R8A8_UNorm;
			case .B8G8R8X8_UNorm_SRGB:
					return .B8G8R8X8_UNorm;
			default:
				return this;
			}
		}
	}
}

namespace GlitchyEngine.Renderer
{
	/**
	 * Defines how to bind a buffer to the pipeline.
	 */
	public enum BufferBindFlags
	{
		/// No binding flags specified
		None = 0,
		/// The Buffer contains vertex data
		Vertex = 1,
		/// The Buffer contains index data
		Index = 2,
		// The Buffer contains constant data
		Constant = 4,
		// ShaderResource?
		// UnorderedAccess?
	}

	public enum BufferMiscFlags : uint8 /* Don't commit, workaround for a beef bug!*/
	{
		None = 0,
		// AllowRawView = 1,
		//Structured = 2,
	}

	public struct BufferDescription
	{
		/**
		 * The size of the buffer in bytes.
		 */
		public uint32 Size;
		
		/**
		 * Identify how the buffer is expected to be read from and written to. Frequency of update is a key factor.
		 * The most common value is typically Default.
		*/
		public Usage Usage;

		public CPUAccessFlags CPUAccess;

		public BufferBindFlags BindFlags;

		public BufferMiscFlags MiscFlags;

		// Strucutred Byte stride.

		public this() => this = default;

		public this(uint32 size, BufferBindFlags bindFlags, Usage usage = .Default, CPUAccessFlags cpuAccess = .None, BufferMiscFlags miscFlags = .None)
		{
			Size = size;
			BindFlags = bindFlags;
			Usage = usage;
			CPUAccess = cpuAccess;
			MiscFlags = miscFlags;
		}
	}

	public enum MapType
	{
		case None;
		case Read;
		case Write;
		case ReadWrite;
		case WriteDiscard;
		case WriteNoOverwrite;

		public bool CanWrite => this == Write ||
			this == ReadWrite ||
			this == WriteDiscard ||
			this == WriteNoOverwrite;

		public bool CanRead => this == Read ||
			this == ReadWrite;
	}

	/// Represents a buffer containing binary data on the GPU.
	public class Buffer : RefCounter
	{
		protected BufferDescription _description;

		public BufferDescription Description => _description;

		protected this() {  }

		/**
		 * Creates a new instance of a Buffer.
		 * @param description The buffer description.
		 */
		public this(BufferDescription description)
		{
			_description = description;
		}
		
		/**
		 * @param data The struct containing the data that will be copied into the buffer.
		 * @param destinationByteOffset The offset in bytes form the start of the destination buffer.
		 * @param mapType Only relevant for dynamic buffers...
		*/
		public Result<void> SetData<T>(T data, uint32 destinationByteOffset = 0, MapType mapType = .Write) where T : struct
		{
			var data;
			return PlatformSetData(&data, (uint32)(sizeof(T)), destinationByteOffset, mapType);
		}

		/**
		 * @param data The span containing the data that will be copied into the buffer.
		 * @param destinationByteOffset The offset in bytes form the start of the destination buffer.
		 * @param mapType Only relevant for dynamic buffers...
		*/
		public Result<void> SetData<T>(Span<T> data, uint32 destinationByteOffset = 0, MapType mapType = .Write) where T : struct
		{
			return PlatformSetData(data.Ptr, (uint32)(data.Length * sizeof(T)), destinationByteOffset, mapType);
		}

		/**
		 * @param data The span containing the data that will be copied into the buffer.
		 * @param destinationByteOffset The offset in bytes form the start of the destination buffer.
		 * @param mapType Only relevant for dynamic buffers...
		*/
		public Result<void> SetData<T>(T* data, uint32 elementCount, uint32 destinationByteOffset = 0, MapType mapType = .Write) where T : struct
		{
			return PlatformSetData(data, elementCount * (uint32)sizeof(T), destinationByteOffset, mapType);
		}

		public Result<void> SetData<T, CLength>(T[CLength] data, uint32 destinationByteOffset = 0, MapType mapType = .Write) where T : struct where CLength : const int
		{
			var data;
			return PlatformSetData(&data, (uint32)sizeof(T[CLength]), destinationByteOffset, mapType);
		}

		/**
		 * // Todo: as soon as Beef supports generic method override, change to generic?
		 * Platform specific implementation of SetData.
		 * @param data The pointer to the source data that will be copied to the buffer.
		 * @param data The number of bytes that will be copied.
		 * @param dstByteOffset The offset from the start of the target buffer.
		 */
		protected extern Result<void> PlatformSetData(void* data, uint32 byteLength, uint32 dstByteOffset, MapType mapType);
	}
	
	/**
	 * A buffer containing an array of a struct on the GPU.
	 * @param T The type of the struct represented by this buffer.
	 */
	public class Buffer<T> : Buffer where T : struct
	{
		public T Data;

		/**
		 * Creates a new instance of a Buffer<T>
		 * @param description Describes the Buffer. Note: description.Size is ignored, as it will always be sizeof(T).
		 */
		public this(BufferDescription description)
		{
			_description = description;
			_description.Size = (uint32)sizeof(T);
		}

		// Todo: perhaps add a constructor that takes all parameters from description except Size

		/**
		 * Uploads the date to the GPU.
		 */
		[Inline]
		public void Update()
		{
			PlatformSetData(&Data, (uint32)sizeof(T), 0, .WriteDiscard);
		}
	}
}
