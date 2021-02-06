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
			VertexShader = new VertexShader(_context, vsPath, vsEntry);
			PixelShader = new PixelShader(_context, psPath, psEntry);

			Reflect();
		}

		private void Reflect()
		{

		}
	}
}
