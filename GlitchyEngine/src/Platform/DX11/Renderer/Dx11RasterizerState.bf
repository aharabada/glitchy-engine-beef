#if GE_GRAPHICS_DX11

using DirectX.D3D11;
using GlitchyEngine.Platform.DX11;

using internal GlitchyEngine.Renderer;
using internal GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.Renderer
{
	extension FillMode
	{
		public static explicit operator DirectX.D3D11.FillMode(Self fm) => fm == .Solid ? .Solid : .Wireframe;
	}
	
	extension CullMode
	{
		public static explicit operator DirectX.D3D11.CullMode(Self cm)
		{
			if(cm == .None)
				return .None;
			
			if(cm == .Front)
				return .Front;
			
			return .Back;
		}
	}

	extension RasterizerStateDescription
	{
		public static explicit operator DirectX.D3D11.RasterizerStateDescription(Self description)
		{
			DirectX.D3D11.RasterizerStateDescription result = .();
			result.FillMode = (.)description.FillMode;
			result.CullMode = (.)description.CullMode;
			result.FrontCounterClockwise = description.FrontCounterClockwise;
			result.DepthBias = description.DepthBias;
			result.DepthBiasClamp = description.DepthBiasClamp;
			result.SlopeScaledDepthBias = description.SlopeScaledDepthBias;
			result.DepthClipEnable = description.DepthClipEnabled;
			result.ScissorEnable = description.ScissorEnabled;
			result.MultisampleEnable = description.MultisampleEnabled;
			result.AntialiasedLineEnable = description.AntialiasedLineEnabled;

			return result;
		}
	}

	extension RasterizerState
	{
		internal DirectX.D3D11.RasterizerStateDescription nativeDescription;
		internal ID3D11RasterizerState* nativeRasterizerState ~ _?.Release();

		public override this(GlitchyEngine.Renderer.RasterizerStateDescription description)
		{
			_description = description;
			nativeDescription = (.)_description;

			var result = NativeDevice.CreateRasterizerState(ref nativeDescription, &nativeRasterizerState);
			if(result.Failed)
			{
				Log.EngineLogger.Error($"Failed to create rasterizer state. Message({(int)result}): {result}");
			}
		}
	}
}

#endif
