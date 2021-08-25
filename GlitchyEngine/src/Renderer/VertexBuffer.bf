using System;
namespace GlitchyEngine.Renderer
{
	public struct VertexBufferBinding
	{
		public VertexBuffer Buffer;
		public uint32 Stride;
		public uint32 Offset;

		public this(VertexBuffer buffer, uint32 stride, uint32 offset = 0)
		{
			Buffer = buffer;
			Stride = stride;
			Offset = offset;
		}
	}

	public class VertexBuffer : Buffer
	{
		private VertexBufferBinding _defaultBinding;

		private Type _vertexType;

		public Type VertexDataType => _vertexType;

		public VertexBufferBinding Binding => _defaultBinding;

		public this(GraphicsContext context, Type vertexType, uint32 vertexCount, Usage usage = .Default, CPUAccessFlags cpuAccess = .None) :
			this(context, (.)vertexType.Stride, vertexCount, usage, cpuAccess)
		{
			_vertexType = vertexType;
		}

		public this(GraphicsContext context, uint32 vertexStride, uint32 vertexCount, Usage usage = .Default, CPUAccessFlags cpuAccess = .None) : base(context)
		{
			_vertexType = null;

			_description = .(){
				Size = (vertexStride * vertexCount),
				Usage = usage,
				CPUAccess = cpuAccess,
				BindFlags = .Vertex,
				MiscFlags = .None
			};

			_defaultBinding = .(this, vertexStride, 0);
		}

		[Inline]
		public static implicit operator VertexBufferBinding(Self buffer) => buffer._defaultBinding;
	}
}
