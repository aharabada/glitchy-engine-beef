#if GE_GRAPHICS_DX11

using DirectX.Common;
using DirectX.D3D11;
using GlitchyEngine.Platform.DX11;

using internal GlitchyEngine.Renderer;
using internal GlitchyEngine.Platform.DX11;

namespace DirectX.D3D11
{
	extension Filter
	{
		public static Filter SamplerToFilter(GlitchyEngine.Renderer.SamplerStateDescription samplerDesc)
		{
			/*
			While I'm writing this Function it turns out that the numbers in the D3D11_FILTER-enum
			aren't as random as I thought. One could even say they are quite clever.

			Explanation:
			If the Mip filter is Linear the first bit (LSB) will be 1	(Filter = 0x01)
			If the Mag filter is Linear the third bit will be 1			(Filter = 0x04)
			If the Min filter is Linear the fifth bit will be 1			(Filter = 0x10)
			if any of them is Point their respective bit will be 0

			If the filter is Anisotropic the Filter will be 0x0101'0101.

			Comparison-, Minimum- and Maximum-Filter modes will also set their respective bit.
			(0x80, 0x100 and 0x180 respectively)
			*/

			Filter output = .Min_Mag_Mip_Point;

			// Mip filter
			if(samplerDesc.MipFilter == .Linear)
			{
				output |= .Min_Mag_Point_Mip_Linear;
			}
			else if(samplerDesc.MipFilter == .Anisotropic)
			{
				output = .Anisotropic;
			}

			// Mag filter
			if(samplerDesc.MagFilter == .Linear)
			{
				output |= .Min_Point_Mag_Linear_Mip_Point;
			}
			else if(samplerDesc.MagFilter == .Anisotropic)
			{
				output = .Anisotropic;
			}

			// Min filter
			if(samplerDesc.MinFilter == .Linear)
			{
				output |= .Min_Linear_Mag_Mip_Point;
			}
			else if(samplerDesc.MinFilter == .Anisotropic)
			{
				output = .Anisotropic;
			}

			// Sets filter mode bit
			switch(samplerDesc.FilterMode)
			{
			case .Default:
				output |= .Min_Mag_Mip_Point;
			case .Comparison:
				output |= .Comparison_Min_Mag_Mip_Point;
			case .Minimum:
				output |= .Minimum_Min_Mag_Mip_Point;
			case .Maximum:
				output |= .Maximum_Min_Mag_Mip_Point;
			}

			return output;
		}
	}
}

namespace GlitchyEngine.Renderer
{
	extension SamplerStateDescription
	{
		typealias NativeDesc = DirectX.D3D11.SamplerStateDescription;

		public void ToNative(out NativeDesc samplerDesc)
		{
			samplerDesc.Filter = .SamplerToFilter(this);

			samplerDesc.ComparisonFunc = (.)ComparisonFunction;

			samplerDesc.AddressU = (.)AddressModeU;
			samplerDesc.AddressV = (.)AddressModeV;
			samplerDesc.AddressW = (.)AddressModeW;

			samplerDesc.MipLODBias = MipLODBias;
			samplerDesc.MinLOD = MipMinLOD;
			samplerDesc.MaxLOD = MipMaxLOD;

			samplerDesc.MaxAnisotropy = MaxAnisotropy;

			samplerDesc.BorderColor = BorderColor;
		}
	}

	extension SamplerState
	{
		internal ID3D11SamplerState* nativeSamplerState ~ _?.Release();

		protected override void PlatformCreateSamplerState()
		{
			Debug.Profiler.ProfileResourceFunction!();

			_desc.ToNative(var nativeDesc);

			HResult result = NativeDevice.CreateSamplerState(ref nativeDesc, &nativeSamplerState);

			Log.EngineLogger.Assert(result.Succeeded, scope $"Failed to create SamplerState. Error({(int)result}): {result}");
		}

		public override void Bind(uint32 slot)
		{
			NativeContext.VertexShader.SetSamplers(slot, 1, &nativeSamplerState);
			NativeContext.PixelShader.SetSamplers(slot, 1, &nativeSamplerState);
		}
	}
}

#endif
