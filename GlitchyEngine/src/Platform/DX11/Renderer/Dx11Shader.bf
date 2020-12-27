using System;
using GlitchyEngine.Renderer;
using DirectX.Common;
using DirectX.D3D11;
using DirectX.D3DCompiler;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
	extension Shader
	{
		internal static void PlattformCompileShaderFromSource(String code, ShaderDefine[] macros, String entryPoint, String target, ShaderCompileFlags compileFlags, out ID3DBlob* shaderBlob)
		{
			ShaderMacro* nativeMacros = macros == null ? null : new:ScopedAlloc! ShaderMacro[macros.Count]*; 

			for(int i < macros?.Count ?? 0)
			{
				nativeMacros[i].Name = macros[i].Name.ToScopedNativeWChar!();
				nativeMacros[i].Definition = macros[i].Definition.ToScopedNativeWChar!();
			}

			// Todo: sourceName, includes,
			// Todo: variable shader target?

			ID3DBlob* errorBlob = null;

			shaderBlob = null;
			var result = D3DCompiler.D3DCompile(code.CStr(), (.)code.Length, null, nativeMacros, null, entryPoint, target, compileFlags, .None, &shaderBlob, &errorBlob);
			if(result.Failed)
			{
				StringView str = StringView((char8*)errorBlob.GetBufferPointer(), errorBlob.GetBufferSize());
				Log.EngineLogger.Error($"Failed to compile Shader: Error Code({(int)result}): {result} | Error Message: {str}");
			}
		}
	}
}
