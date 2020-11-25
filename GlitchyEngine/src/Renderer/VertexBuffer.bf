using System;
namespace GlitchyEngine.Renderer
{
	public struct VertexBufferBinding
	{
		public Buffer Buffer;
		public uint32 Stride;
		public uint32 Offset;

		public this(Buffer buffer, uint32 stride, uint32 offset = 0)
		{
			Buffer = buffer;
			Stride = stride;
			Offset = offset;
		}
	}

	public class VertexBuffer<T> : Buffer where T: struct, IVertexData
	{
		private VertexBufferBinding _defaultBinding;

		public VertexBufferBinding Binding => _defaultBinding;

		public this(GraphicsContext context, uint32 vertexCount, Usage usage = .Default, CPUAccessFlags cpuAccess = .None) : base(context)
		{
			_description = .(){
				Size = ((uint32)sizeof(T) * vertexCount),
				Usage = usage,
				CPUAccess = cpuAccess,
				BindFlags = .Vertex,
				MiscFlags = .None
			};

			_defaultBinding = .(this, (.)sizeof(T), 0);
		}

		public Result<void> SetData(Span<T> data, uint32 destinationVertexOffset = 0, MapType mapType = .Write)
		{
			return SetData<T>(data, destinationVertexOffset * (uint32)sizeof(T));
		}

		[Inline]
		public static implicit operator VertexBufferBinding(Self buffer) => buffer._defaultBinding;
	}
}
