using DirectX.D3D11;
using DirectX.DXGI;

namespace GlitchyEngine.Platform.DX11
{
	public static class Dx11Cheater
	{
		public static ID3D11Device* Device;
		public static ID3D11DeviceContext* ImmediateContext;

		public static ID3D11DeviceContext* Context => ImmediateContext;

		public static IDXGISwapChain* SwapChain;
		public static ID3D11RenderTargetView* BackbufferTarget;
		public static Viewport BackbufferViewport;
	}
}
