#if GE_GRAPHICS_DX11

using System;
using DirectX;
using DirectX.D3D11;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
	extension Effect
	{
		protected override void Compile(String vsPath, String vsEntry, String psPath, String psEntry)
		{
			// Todo: macros
			VertexShader = new VertexShader(vsPath, vsEntry);
			PixelShader = new PixelShader(psPath, psEntry);

			Reflect();
		}

		private void Reflect()
		{

		}
	}
}

#endif
