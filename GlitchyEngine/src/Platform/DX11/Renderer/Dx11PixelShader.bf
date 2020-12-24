using System;
using DirectX.D3D11;
using DirectX.D3DCompiler;
using DirectX.D3D11Shader;
using DirectX.Common;

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

	extension PixelShader
	{
		internal ID3D11PixelShader* nativeShader ~ _?.Release();

		public override void CompileFromSource(String code, String entryPoint, ShaderDefine[] macros = null)
		{
			ShaderCompileFlags flags = .Default;

#if DEBUG
			flags |= .Debug;
#else
			flags |= .OptimizationLevel3;
#endif

			Shader.PlattformCompileShaderFromSource(code, macros, entryPoint, "ps_5_0", flags, let shaderBlob);

			var result = _context.nativeDevice.CreatePixelShader(shaderBlob.GetBufferPointer(), shaderBlob.GetBufferSize(), null, &nativeShader);
			if(result.Failed)
			{
				Log.EngineLogger.Error($"Failed to create pixel shader: Message ({(int)result}): {result}");
			}

			//Reflect(shaderBlob);
			
			shaderBlob?.Release();
		}

		internal void Reflect(ID3DBlob* shaderCode)
		{
			ID3D11ShaderReflection* reflection = null;
			var result = D3DCompiler.D3DReflect(shaderCode.GetBufferPointer(), shaderCode.GetBufferSize(), &reflection);
			if(result.Failed)
			{
				Log.EngineLogger.Error($"Failed to reflect pixel shader: Message ({(int)result}): {result}");
			}

			reflection.GetDescription(let desc);
			uint32 cBufferCount = desc.ConstantBuffers;

			for(uint32 i < cBufferCount)
			{
				var bufferReflection = reflection.GetConstantBufferByIndex(i);
				bufferReflection.GetDescription(let bufferDesc);
			}
			reflection.Release();
		}
	}

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
