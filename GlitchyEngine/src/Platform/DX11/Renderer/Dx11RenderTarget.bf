#if GE_D3D11

using DirectX.Common;
using DirectX.D3D11;
using GlitchyEngine.Platform.DX11;

using internal GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.Renderer
{
	using internal GlitchyEngine.Renderer;

	extension RenderTarget2D
	{
		protected internal ID3D11Texture2D* _nativeTexture ~ _?.Release();
		protected internal ID3D11ShaderResourceView* _nativeResourceView ~ _?.Release();
		protected internal ID3D11RenderTargetView* _nativeRenderTargetView ~ _?.Release();

		private void ReleaseAndNullify()
		{
			ReleaseAndNullify!(_nativeTexture);
			ReleaseAndNullify!(_nativeResourceView);
			ReleaseAndNullify!(_nativeRenderTargetView);

			ReleaseRefAndNullify!(_depthStenilTarget);
		}

		public override void Resize(uint32 width, uint32 height)
		{
			ReleaseAndNullify();

			_description.Width = width;
			_description.Height = height;

			ApplyChanges();
		}

		protected override void PlatformApplyChanges()
		{
			ReleaseAndNullify();

			PlatformCreateTexture();

			if(_description.DepthStencilFormat != .None)
			{
				_depthStenilTarget = new DepthStencilTarget(_description.Width, _description.Height, _description.DepthStencilFormat);
			}
		}

		private void PlatformCreateTexture()
		{
			Texture2DDescription desc = .()
			{
				Width = _description.Width,
				Height = _description.Height,
				ArraySize = _description.ArraySize,
				MipLevels = _description.MipLevels,
				Format = _description.PixelFormat,
				// Always bindable as ShaderResource and RenderTarget
				BindFlags = .ShaderResource | .RenderTarget,
				CpuAccessFlags = (.)_description.CpuAccess,
				// 2D RenderTarget never has misc flags
				MiscFlags = .None,
				SampleDesc = .(_description.SampleCount, _description.SampleQuality),
				// RenderTarget has always Default usage
				Usage = .Default
			};

			var result = NativeDevice.CreateTexture2D(ref desc, null, &_nativeTexture);
			Log.EngineLogger.Assert(result.Succeeded, "Failed to create RenderTarget2D");

			CreateViews();
		}

		private void CreateViews()
		{
			var result = NativeDevice.CreateShaderResourceView(_nativeTexture, null, &_nativeResourceView);
			Log.EngineLogger.Assert(result.Succeeded, "Failed to create resource view");

			result = NativeDevice.CreateRenderTargetView(_nativeTexture, null, &_nativeRenderTargetView);
			Log.EngineLogger.Assert(result.Succeeded, "Failed to create render target view");
		}
	}
}

#endif
