using System;
using DirectX.D3D11;
using DirectX.D3DCompiler;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
	extension PixelShader
	{
		internal ID3D11PixelShader* nativeShader ~ _?.Release();

		public override void CompileFromSource(String code, String entryPoint, ShaderDefine[] macros = null)
		{
			Shader.PlattformCompileShaderFromSource(code, macros, entryPoint, "ps_5_0", DefaultCompileFlags, out nativeCode);

			var result = _context.nativeDevice.CreatePixelShader(nativeCode.GetBufferPointer(), nativeCode.GetBufferSize(), null, &nativeShader);
			if(result.Failed)
			{
				Log.EngineLogger.Error($"Failed to create pixel shader: Message ({(int)result}): {result}");
			}

			Reflect(nativeCode);
		}
	}
}
