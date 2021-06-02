using DirectX.D3D11;
using internal GlitchyEngine.Renderer;

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
			}
		}
	}

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
			_context.nativeDevice.CreateTexture2D(ref desc, null, &tex);

			_context.nativeDevice.CreateDepthStencilView(tex, null, &nativeView);

			tex.Release();
		}

		public override void Bind()
		{
			_context.SetDepthStencilTarget(this);
		}

		public override void Clear(float depthValue, uint8 stencilValue, DepthStencilClearFlag clearFlags)
		{
			_context.nativeContext.ClearDepthStencilView(nativeView, (.)clearFlags, depthValue, stencilValue);
		}
	}
}
