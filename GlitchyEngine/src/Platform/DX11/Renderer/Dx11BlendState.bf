using DirectX.D3D11;
using DirectX.Common;
using GlitchyEngine.Math;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
	extension BlendState
	{
		internal ID3D11BlendState* nativeBlendState ~ _?.Release();

		public override void Bind(ColorRGBA blendFactor)
		{
			_context.nativeContext.OutputMerger.SetBlendState(nativeBlendState, blendFactor);
		}

		protected override void PlatformCreateBlendState()
		{
			BlendDescription nativeDesc = .Default;
			nativeDesc.IndependentBlendEnable = _desc.IndependentBlendEnable;
			nativeDesc.AlphaToCoverageEnable = _desc.AlphaToCoverageEnable;

			for(int i = 0; i < 8; i++)
			{
				nativeDesc.RenderTarget[i].BlendEnable = _desc.RenderTarget[i].BlendEnable;
				nativeDesc.RenderTarget[i].SourceBlend = _desc.RenderTarget[i].SourceBlend;
				nativeDesc.RenderTarget[i].DestinationBlend = _desc.RenderTarget[i].DestinationBlend;
				nativeDesc.RenderTarget[i].BlendOperation = _desc.RenderTarget[i].BlendOperation;
				nativeDesc.RenderTarget[i].SourceBlendAlpha = _desc.RenderTarget[i].SourceBlendAlpha;
				nativeDesc.RenderTarget[i].DestinationBlendAlpha = _desc.RenderTarget[i].DestinationBlendAlpha;
				nativeDesc.RenderTarget[i].BlendOperationAlpha = _desc.RenderTarget[i].BlendOperationAlpha;
				nativeDesc.RenderTarget[i].RenderTargetWriteMask = _desc.RenderTarget[i].RenderTargetWriteMask;
			}

			HResult result = _context.nativeDevice.CreateBlendState(ref nativeDesc, &nativeBlendState);

			Log.EngineLogger.Assert(result.Succeeded, scope $"Failed to create blend state. Error({(int)result}): {result}");
		}
	}
}
