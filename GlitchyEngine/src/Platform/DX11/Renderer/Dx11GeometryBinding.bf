using System;
using DirectX.D3D11;

namespace GlitchyEngine.Renderer
{
	using internal GlitchyEngine.Renderer;

	extension GeometryBinding
	{
		internal ID3D11Buffer*[DirectX.D3D11.D3D11_IA_VERTEX_INPUT_RESOURCE_SLOT_COUNT] nativeBuffers;
		internal uint32[DirectX.D3D11.D3D11_IA_VERTEX_INPUT_RESOURCE_SLOT_COUNT] bufferStrides;
		internal uint32[DirectX.D3D11.D3D11_IA_VERTEX_INPUT_RESOURCE_SLOT_COUNT] bufferOffsets;
		
		internal ID3D11InputLayout* nativeVertexLayout;
		internal ID3D11Buffer* nativeIndexBuffer;

		public ~this()
		{
			for(ID3D11Buffer* buffer in nativeBuffers)
			{
				buffer?.Release();
			}
			
			nativeVertexLayout?.Release();
			nativeIndexBuffer?.Release();
		}

		protected override void PlatformSetVertexBuffer(VertexBufferBinding binding, uint32 slot)
		{
			Log.EngineLogger.Assert(slot < nativeBuffers.Count, "The buffer slot has to be in the range from 0 to 31.");

			VertexBuffer vertexBuffer = binding.Buffer;

			if(vertexBuffer != null)
			{
				Log.EngineLogger.Assert(vertexBuffer.nativeDescription.BindFlags.HasFlag(.VertexBuffer),
					scope $"Buffer ({vertexBuffer.nativeBuffer.GetDebugName(.. scope .())}) must have VertexBuffer-flag set to be bound as a vertex buffer.");

				nativeBuffers[slot]?.Release();

				nativeBuffers[slot] = vertexBuffer.nativeBuffer..AddRef();

				bufferStrides[slot] = binding.Stride;
				bufferOffsets[slot] = binding.Offset;
			}
			else
			{
				nativeBuffers[slot]?.Release();

				nativeBuffers[slot] = null;
				bufferStrides[slot] = 0;
				bufferOffsets[slot] = 0;
			}
		}

		protected override void PlatformSetVertexLayout(VertexLayout vertexLayout)
		{
			nativeVertexLayout?.Release();
			nativeVertexLayout = vertexLayout?.nativeLayout..AddRef();
		}

		protected override void PlatformSetIndexBuffer(IndexBuffer indexBuffer)
		{
			Log.EngineLogger.Assert(indexBuffer.nativeDescription.BindFlags.HasFlag(.IndexBuffer),
				scope $"Buffer ({indexBuffer.nativeBuffer.GetDebugName(.. scope .())}) must have IndexBuffer-flag set to be bound as an index buffer.");

			nativeIndexBuffer?.Release();
			nativeIndexBuffer = indexBuffer.nativeBuffer..AddRef();
		}

		protected override void PlatformSetPrimitiveTopology(GlitchyEngine.Renderer.PrimitiveTopology topology)
		{

		}

		public override void Bind(GraphicsContext context = null)
		{
			var context;
			context ??= _context;

			context.nativeContext.InputAssembler.SetVertexBuffers(0, nativeBuffers.Count, &nativeBuffers, &bufferStrides, &bufferOffsets);
			context.nativeContext.InputAssembler.SetInputLayout(_vertexLayout.nativeLayout);
			context.nativeContext.InputAssembler.SetPrimitiveTopology((.)_primitiveTopology);

			if(_indexBuffer != null)
				context.nativeContext.InputAssembler.SetIndexBuffer(_indexBuffer.nativeBuffer, _indexBuffer.Format == .Index32Bit ? .R32_UInt : .R16_UInt, _indexByteOffset);
		}

		public void Unbind(GraphicsContext context = null)
		{
			var context;
			context ??= _context;

			ID3D11Buffer*[nativeBuffers.Count] nullBuffers = .();
			uint32[nativeBuffers.Count] zeroStrides = .();
			uint32[nativeBuffers.Count] zeroOffsets = .();

			context.nativeContext.InputAssembler.SetVertexBuffers(0, nativeBuffers.Count, &nullBuffers, &zeroStrides, &zeroOffsets);
			context.nativeContext.InputAssembler.SetInputLayout(null);
			context.nativeContext.InputAssembler.SetPrimitiveTopology(.Undefined);
			
			context.nativeContext.InputAssembler.SetIndexBuffer(null, .R16_UNorm, 0);
		}
	}
}
