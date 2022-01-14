#if GE_GRAPHICS_DX11

using DirectX.D3D11;
using GlitchyEngine.Platform.DX11;

using internal GlitchyEngine.Renderer;
using internal GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.Renderer
{
	internal typealias D3DDepthStencilStateDesc = DirectX.D3D11.DepthStencilStateDescription;
	internal typealias DxDSSDesc = DirectX.D3D11.DepthStencilStateDescription;
	internal typealias GEDSSDesc = GlitchyEngine.Renderer.DepthStencilStateDescription;
	
	internal typealias DxDepthStencilOpDesc = DirectX.D3D11.DepthStencilOperationDescription;

	extension StencilOperation
	{
		public static explicit operator DirectX.D3D11.StencilOperation(Self self)
		{
			return (.)self.Underlying;
		}
	}

	extension DepthStencilOperationDescription
	{
		public static explicit operator DxDepthStencilOpDesc(Self desc)
		{
			return DxDepthStencilOpDesc((.)desc.StencilFailOperation, (.)desc.StencilDepthFailOperation,
				(.)desc.StencilPassOperation, (.)desc.StencilFunction);
		}
	}

	extension DepthStencilStateDescription
	{
		public static explicit operator DxDSSDesc(Self desc)
		{
			return DxDSSDesc(desc.DepthEnabled, desc.WriteDepth ? .All : .Zero, (.)desc.DepthFunction, desc.StencilEnabled,
				desc.StencilReadMask, desc.StencilWriteMask, (.)desc.FrontFace, (.)desc.BackFace);
		}
	}

	extension DepthStencilState
	{
		internal DxDSSDesc nativeDescription;
		internal ID3D11DepthStencilState* nativeDepthStencilState ~ _?.Release();

		public this(GEDSSDesc description)
		{
			Debug.Profiler.ProfileResourceFunction!();

			_description = description;
			nativeDescription = (.)description;

			var result = NativeDevice.CreateDepthStencilState(ref nativeDescription, &nativeDepthStencilState);
			if (result.Failed)
			{
				Log.EngineLogger.Error($"Failed to create depth stencil state. Message({(int)result}): {result}");
			}
		}
	}
}

#endif
