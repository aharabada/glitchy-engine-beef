#if GE_GRAPHICS_DX11

using DirectX.D3D11;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
	extension BufferCollection
	{
		public static override int MaxBufferSlotCount => DirectX.D3D11.D3D11_COMMONSHADER_CONSTANT_BUFFER_API_SLOT_COUNT;

		internal ID3D11Buffer*[DirectX.D3D11.D3D11_COMMONSHADER_CONSTANT_BUFFER_API_SLOT_COUNT] nativeBuffers;

		protected internal override void PlatformFetchNativeBuffers()
		{
			Debug.Profiler.ProfileRendererFunction!();

			for(let buffer in _buffers)
			{
				nativeBuffers[@buffer] = buffer.Buffer?.nativeBuffer;
			}
		}
	}
}

#endif
