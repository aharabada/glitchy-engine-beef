#if GE_GRAPHICS_DX11

using DirectX.D3D11;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
	extension BufferCollection
	{
		internal ID3D11Buffer*[DirectX.D3D11.D3D11_COMMONSHADER_CONSTANT_BUFFER_API_SLOT_COUNT] nativeBuffers;

		internal void PlatformFetchNativeBuffers()
		{
			Debug.Profiler.ProfileRendererFunction!();

			// Clear
			nativeBuffers = .();

			for(let buffer in _buffers)
			{
				nativeBuffers[buffer.Index] = buffer.Buffer.nativeBuffer;
			}
		}
	}
}

#endif
