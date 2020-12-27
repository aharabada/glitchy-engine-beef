using System;
using GlitchyEngine.Renderer;
using DirectX.Common;
using DirectX.D3D11;
using DirectX.D3DCompiler;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
	extension VertexShader
	{
		internal ID3D11VertexShader* nativeShader ~ _?.Release();

		internal ID3DBlob* nativeCode ~ _?.Release();

		public override void CompileFromSource(String code, String entryPoint, ShaderDefine[] macros = null)
		{
			ShaderCompileFlags flags = .Default;

#if DEBUG
			flags |= .Debug;
#else
			flags |= .OptimizationLevel3;
#endif

			Shader.PlattformCompileShaderFromSource(code, macros, entryPoint, "vs_5_0", flags, out nativeCode);

			var result = _context.nativeDevice.CreateVertexShader(nativeCode.GetBufferPointer(), nativeCode.GetBufferSize(), null, &nativeShader);
			if(result.Failed)
			{
				Log.EngineLogger.Error($"Failed to create vertex shader: Message ({(int)result}): {result}");
			}

			//int i = nativeCode?.Release() ?? (uint32)-1;
		}
	}
}
