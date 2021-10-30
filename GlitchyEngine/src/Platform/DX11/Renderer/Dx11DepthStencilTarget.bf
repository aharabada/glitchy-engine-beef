#if GE_GRAPHICS_DX11

using DirectX.D3D11;
using internal GlitchyEngine.Renderer;

using GlitchyEngine.Platform.DX11;
using internal GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.Renderer
{
	extension DepthStencilFormat
	{
		public static explicit operator Format(Self self)
		{
			switch(self)
			{
			case .D16_UNorm:
				return .D16_UNorm;
			case .D24_UNorm_S8_UInt:
				return .D24_UNorm_S8_UInt;
			case .D32_Float:
				return .D32_Float;
			case .D32_Float_S8X24_UInt:
				return .D32_Float_S8X24_UInt;
			case .None:
				Log.EngineLogger.Assert(false, "None is not a valid depth stencil format");
				return .Unknown;
			}
		}
	}

	// TODO: Depth stencil target is technically just a RenderTarget
	extension DepthStencilTarget
	{
		internal ID3D11DepthStencilView* nativeView ~ _?.Release();

		protected override void PlatformCreate()
		{
			Texture2DDescription desc = .();
			desc.Format = (.)_format;
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
