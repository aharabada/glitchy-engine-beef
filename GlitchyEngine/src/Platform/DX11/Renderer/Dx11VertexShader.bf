#if GE_GRAPHICS_DX11

using System;
using GlitchyEngine.Renderer;
using DirectX.D3D11;
using DirectX.D3DCompiler;
using GlitchyEngine.Platform.DX11;
using GlitchyEngine.Content;

using internal GlitchyEngine.Renderer;
using internal GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.Renderer
{
	extension VertexShader
	{
		public override void CompileFromSource(StringView code, StringView? fileName, String entryPoint, IContentManager contentManager = null, ShaderDefine[] macros = null)
		{
			Debug.Profiler.ProfileResourceFunction!();

			Shader.PlattformCompileShaderFromSource(code, fileName, macros, entryPoint, "vs_5_0", DefaultCompileFlags, contentManager, out nativeCode);

			{
				Debug.Profiler.ProfileResourceScope!("CreateNativeVertexShader");

				var result = NativeDevice.CreateVertexShader(nativeCode.GetBufferPointer(), nativeCode.GetBufferSize(), null, (ID3D11VertexShader**)&nativeShader);
				if(result.Failed)
				{
					Log.EngineLogger.Error($"Failed to create vertex shader: Message ({(int)result}): {result}");
				}
			}

			Reflect(nativeCode);
		}
	}
}

#endif
