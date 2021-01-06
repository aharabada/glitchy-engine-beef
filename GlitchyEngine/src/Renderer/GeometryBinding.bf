using System;
using System.Collections;

namespace GlitchyEngine.Renderer
{
	public class GeometryBinding
	{
		internal GraphicsContext _context;

		internal List<VertexBufferBinding> _vertexBuffers = new .() ~ delete _;
		internal IndexBuffer _indexBuffer;
		internal VertexLayout _vertexLayout;
		internal uint32 _indexByteOffset;
		internal uint32 _indexCount;
		internal PrimitiveTopology _primitiveTopology;

		public this(GraphicsContext context)
		{
			_context = context;
		}

		public VertexBufferBinding GetVertexBuffer(uint32 slot)
		{
			return _vertexBuffers[slot];
		}

		public IndexBuffer GetIndexBuffer()
		{
			return _indexBuffer;
		}
		
		public VertexLayout GetVertexLayout()
		{
			return _vertexLayout;
		}

		[Inline]
		public uint32 IndexByteOffset => _indexByteOffset;

		[Inline]
		public uint32 IndexCount => _indexCount;

		[Inline]
		public PrimitiveTopology PrimitiveTopology => _primitiveTopology;

		public void SetVertexBufferSlot(VertexBufferBinding vertexBufferBinding, uint32 slot)
		{
			_vertexBuffers.Add(vertexBufferBinding);

			PlatformSetVertexBuffer(vertexBufferBinding, slot);
		}

		protected extern void PlatformSetVertexBuffer(VertexBufferBinding vertexBuffer, uint32 slot);

		public void SetVertexLayout(VertexLayout vertexLayout)
		{
			_vertexLayout = vertexLayout;
			PlatformSetVertexLayout(vertexLayout);
		}
		
		protected extern void PlatformSetVertexLayout(VertexLayout layout);

		public void SetPrimitiveTopology(PrimitiveTopology topology)
		{
			_primitiveTopology = topology;
			PlatformSetPrimitiveTopology(topology);
		}

		protected extern void PlatformSetPrimitiveTopology(PrimitiveTopology topology);

		public void SetIndexBuffer(IndexBuffer indexBuffer, uint32 byteOffset = 0, uint32 indexCount = (.)-1)
		{
			_indexBuffer = indexBuffer;
			_indexByteOffset = byteOffset;

			if(indexCount == (.)-1)
			{
				_indexCount = _indexBuffer.IndexCount - (uint32)(_indexByteOffset / _indexBuffer.Format.IndexSize);
			}
			else
			{
				_indexCount = indexCount;
			}

			PlatformSetIndexBuffer(indexBuffer);
		}
		
		protected extern void PlatformSetIndexBuffer(IndexBuffer indexBuffer);

		public extern void Bind(GraphicsContext context = null);

		public extern void Unbind(GraphicsContext context = null);
	}
}
