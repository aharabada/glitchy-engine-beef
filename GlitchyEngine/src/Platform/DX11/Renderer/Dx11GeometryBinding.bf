#if GE_GRAPHICS_DX11

using System;
using DirectX.D3D11;
using GlitchyEngine.Platform.DX11;

using internal GlitchyEngine.Renderer;
using internal GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.Renderer
{
	extension GeometryBinding
	{
		internal ID3D11Buffer*[DirectX.D3D11.D3D11_IA_VERTEX_INPUT_RESOURCE_SLOT_COUNT] nativeBuffers;
		internal uint32[DirectX.D3D11.D3D11_IA_VERTEX_INPUT_RESOURCE_SLOT_COUNT] bufferStrides;
		internal uint32[DirectX.D3D11.D3D11_IA_VERTEX_INPUT_RESOURCE_SLOT_COUNT] bufferOffsets;
		
		internal ID3D11Buffer* nativeIndexBuffer;

		public ~this()
		{
			for(ID3D11Buffer* buffer in nativeBuffers)
			{
				buffer?.Release();
			}
			
			nativeIndexBuffer?.Release();
		}

		protected override void PlatformSetVertexBuffer(VertexBufferBinding binding, uint32 slot)
		{
			Debug.Profiler.ProfileResourceFunction!();

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
		}

		protected override void PlatformSetIndexBuffer(IndexBuffer indexBuffer)
		{
			Debug.Profiler.ProfileResourceFunction!();

			Log.EngineLogger.Assert(indexBuffer.nativeDescription.BindFlags.HasFlag(.IndexBuffer),
				scope $"Buffer ({indexBuffer.nativeBuffer.GetDebugName(.. scope .())}) must have IndexBuffer-flag set to be bound as an index buffer.");

			nativeIndexBuffer?.Release();
			nativeIndexBuffer = indexBuffer.nativeBuffer..AddRef();
		}

		protected override void PlatformSetPrimitiveTopology(GlitchyEngine.Renderer.PrimitiveTopology topology)
		{

		}

		public override void Bind()
		{
			Debug.Profiler.ProfileRendererFunction!();
			
			using (ContextMonitor.Enter())
			{
				NativeContext.InputAssembler.SetVertexBuffers(0, nativeBuffers.Count, &nativeBuffers, &bufferStrides, &bufferOffsets);
				GraphicsContext.Get().SetVertexLayout(_vertexLayout);
				NativeContext.InputAssembler.SetPrimitiveTopology((.)_primitiveTopology);
	
				if(_indexBuffer != null)
					NativeContext.InputAssembler.SetIndexBuffer(_indexBuffer.nativeBuffer, _indexBuffer.Format == .Index32Bit ? .R32_UInt : .R16_UInt, _indexByteOffset);
			}
		}

		public override void Unbind()
		{
			Debug.Profiler.ProfileRendererFunction!();

			ID3D11Buffer*[nativeBuffers.Count] nullBuffers = .();
			uint32[nativeBuffers.Count] zeroStrides = .();
			uint32[nativeBuffers.Count] zeroOffsets = .();
			
			using (ContextMonitor.Enter())
			{
				NativeContext.InputAssembler.SetVertexBuffers(0, nativeBuffers.Count, &nullBuffers, &zeroStrides, &zeroOffsets);
				NativeContext.InputAssembler.SetInputLayout(null);
				NativeContext.InputAssembler.SetPrimitiveTopology(.Undefined);
				
				NativeContext.InputAssembler.SetIndexBuffer(null, .R16_UNorm, 0);
			}
		}
	}
}

#endif
