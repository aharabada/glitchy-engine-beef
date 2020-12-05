using System;

namespace GlitchyEngine.Renderer
{
	/**
	 * Identifies expected resource use during rendering.
	 * The usage directly reflects whether a resource is accessible by the CPU and/or the graphics processing unit (GPU). 
	*/
	public enum Usage
	{
		/**
		 * A resource that requires read and write access by the GPU.
		 * This is likely to be the most common usage choice. 
		*/
		Default	= 0,
		/**
		 * A resource that can only be read by the GPU. It cannot be written by the GPU, and cannot be accessed at all by the CPU.
		*/
		Immutable = 1,
		/**
		 * A resource that is accessible by both the GPU (read only) and the CPU (write only). 
		 * A dynamic resource is a good choice for a resource that will be updated by the CPU at least once per frame. 
		 * To update a dynamic resource, use a Map method.
		*/
		Dynamic = 2,
		/**
		 * A resource that supports data transfer (copy) from the GPU to the CPU.
		*/
		Staging = 3
	}

	/**
	 * Defines how the CPU can access a resource.
	 */
	public enum CPUAccessFlags
	{
		/// The CPU has no access to the resource.
		None = 0,
		/// The CPU has read access to the resource.
		Read = 1,
		/// The CPU has write access to the resource.
		Write = 2
	}

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

	public enum BufferMiscFlags
	{
		None = 0,
		//AllowRawView = 1,
		//Structured = 2,
	}

	typealias Format = DirectX.DXGI.Format;

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
	public class Buffer
	{
		internal GraphicsContext _context;

		protected BufferDescription _description;

		public GraphicsContext Context => _context;

		public BufferDescription Description => _description;
		
		protected this(GraphicsContext context)
		{
			_context = context;
		}

		/**
		 * Creates a new instance of a Buffer.
		 * @param description The buffer description.
		 */
		public this(GraphicsContext context, BufferDescription description) : this(context)
		{
			_description = description;
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
		 * @param context The graphics context.
		 * @param description Describes the Buffer. Note: description.Size is ignored, as it will always be sizeof(T).
		 */
		public this(GraphicsContext context, BufferDescription description) : base(context)
		{
			_description = description;
			_description.Size = (uint32)sizeof(T);
		}

		// Todo: perhaps add a constructor that takes all parameters from description except Size

		/**
		 * Uploads the date from @see Data to the GPU.
		 */
		[Inline]
		public void Update()
		{
			PlatformSetData(&Data, (uint32)sizeof(T), 0, .WriteDiscard);
		}
	}
}
