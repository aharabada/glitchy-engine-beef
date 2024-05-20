#if GE_GRAPHICS_DX11

using DirectX.D3D11;
using internal GlitchyEngine.Renderer;

using GlitchyEngine.Platform.DX11;
using internal GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.Renderer
{
	// TODO: Depth stencil target is technically just a RenderTarget
	extension DepthStencilTarget
	{
		internal ID3D11DepthStencilView* nativeView ~ _?.Release();

		protected override void PlatformCreate()
		{
			Debug.Profiler.ProfileResourceFunction!();

			Texture2DDescription desc = .();
			desc.Format = (Format)_format;
			desc.ArraySize = 1;
			desc.BindFlags = .DepthStencil;
			desc.Width = _width;
			desc.Height = _height;
			desc.SampleDesc = .(1, 0);

			ID3D11Texture2D* tex = ?;
			NativeDevice.CreateTexture2D(ref desc, null, &tex);

			NativeDevice.CreateDepthStencilView(tex, null, &nativeView);

			tex.Release();
		}
	}
}

#endif
