using DirectX.D3D11;

namespace GlitchyEngine.Renderer
{
	using internal GlitchyEngine.Renderer;

	extension RenderTarget2D
	{
		protected internal ID3D11RenderTargetView* nativeRenderTargetView ~ _?.Release();

		protected override void CreateRenderTargetPlatform(Texture2DDesc desc)
		{
			nativeRenderTargetView?.Release();
			nativeRenderTargetView = null;

			CreateTexturePlatform(desc, true, null, 0);

			var result = _context.nativeDevice.CreateRenderTargetView(nativeTexture, null, &nativeRenderTargetView);
			Log.EngineLogger.Assert(result.Succeeded, scope $"Failed to create render target view. Error ({result.Underlying}): {result}");
		}
	}
}
