using System;
using System.Collections;
using GlitchyEngine.Content;
using GlitchyEngine.Core;

namespace GlitchyEngine.Renderer
{
	// Todo: Rename to Mesh?
	public class GeometryBinding : Asset
	{
		internal List<VertexBufferBinding> _vertexBuffers = new .() ~ delete _;
		internal IndexBuffer _indexBuffer ~ _?.ReleaseRef();
		internal VertexLayout _vertexLayout ~ _?.ReleaseRef();
		internal uint32 _indexByteOffset;
		internal uint32 _indexCount;
		internal uint32 _instanceCount;
		internal PrimitiveTopology _primitiveTopology;
		internal uint32 _vertexCount;

		public bool IsIndexed => _indexBuffer != null;

		public this()
		{
		}

		public ~this()
		{
			for(let binding in _vertexBuffers)
			{
				binding.Buffer?.ReleaseRef();
			}
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

		public uint32 InstanceCount
		{
			[Inline]
			get => _instanceCount;
			[Inline]
			set => _instanceCount = value;
		}

		public uint32 VertexCount
		{
			[Inline]
			get => _vertexCount;
			[Inline]
			set => _vertexCount = value;
		}

		[Inline]
		public PrimitiveTopology PrimitiveTopology => _primitiveTopology;

		public void SetVertexBufferSlot(VertexBufferBinding vertexBufferBinding, uint32 slot)
		{
			_vertexBuffers.Add(vertexBufferBinding);
			vertexBufferBinding.Buffer.AddRef();

			PlatformSetVertexBuffer(vertexBufferBinding, slot);
		}

		protected extern void PlatformSetVertexBuffer(VertexBufferBinding vertexBuffer, uint32 slot);

		public void SetVertexLayout(VertexLayout vertexLayout)
		{
			_vertexLayout?.ReleaseRef();
			_vertexLayout = vertexLayout..AddRef();
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
			_indexBuffer?.ReleaseRef();
			_indexBuffer = indexBuffer..AddRef();

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

		public extern void Bind();

		public extern void Unbind();
	}
}
