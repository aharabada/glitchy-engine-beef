#if GE_GRAPHICS_DX11

namespace GlitchyEngine.Renderer
{
	extension CPUAccessFlags
	{
		public static explicit operator DirectX.D3D11.CpuAccessFlags(Self cpuAccessFlags)
		{
			DirectX.D3D11.CpuAccessFlags flags = .None;

			if(cpuAccessFlags.HasFlag(.Read))
				flags |= .Read;

			if(cpuAccessFlags.HasFlag(.Write))
				flags |= .Write;

			return flags;
		}
	}
}

#endif
