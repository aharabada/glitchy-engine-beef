#if GE_GRAPHICS_DX11

using System;
using DirectX.D3D11;
using DirectX.D3DCompiler;
using GlitchyEngine.Platform.DX11;

using internal GlitchyEngine.Renderer;
using internal GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.Renderer
{
	extension PixelShader
	{
		internal ID3D11PixelShader* nativeShader ~ _?.Release();

		public override void CompileFromSource(StringView code, StringView? fileName, String entryPoint, ShaderDefine[] macros = null)
		{
			Debug.Profiler.ProfileRendererFunction!();

			Shader.PlattformCompileShaderFromSource(code, fileName, macros, entryPoint, "ps_5_0", DefaultCompileFlags, out nativeCode);
			
			{
				Debug.Profiler.ProfileResourceScope!("CreateNativePixelShader");

				var result = NativeDevice.CreatePixelShader(nativeCode.GetBufferPointer(), nativeCode.GetBufferSize(), null, &nativeShader);
				if(result.Failed)
				{
					Log.EngineLogger.Error($"Failed to create pixel shader: Message ({(int)result}): {result}");
				}
			}

			Reflect(nativeCode);
		}
	}
}

#endif
