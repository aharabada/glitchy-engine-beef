using System;
using GlitchyEngine.Renderer;
using DirectX.Common;
using DirectX.D3D11;
using DirectX.D3DCompiler;
using DirectX.D3D11Shader;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
	extension Shader
	{
		protected const ShaderCompileFlags DefaultCompileFlags =
#if DEBUG
			.Debug;
#else
			.OptimizationLevel3;
#endif

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

		protected internal void Reflect(ID3DBlob* shaderCode)
		{
			ID3D11ShaderReflection* reflection = null;
			var result = D3DCompiler.D3DReflect(shaderCode.GetBufferPointer(), shaderCode.GetBufferSize(), &reflection);
			if(result.Failed)
			{
				Log.EngineLogger.Error($"Failed to reflect shader: Message ({(int)result}): {result}");
			}

			reflection.GetDescription(let desc);
			uint32 cBufferCount = desc.ConstantBuffers;

			for(uint32 i < cBufferCount)
			{
				reflection.GetResourceBindingDescription(i, let bindDesc);

				var bufferReflection = reflection.GetConstantBufferByIndex(i);
				
				bufferReflection.GetDescription(let bufferDesc);

				// ConstantBuffer
				if(bufferDesc.Type == .D3D11_CT_CBUFFER)
				{
					GlitchyEngine.Renderer.BufferDescription cBufferDesc = .(bufferDesc.Size, .Constant, .Dynamic, .Write);

					_buffers.Add(bindDesc.BindPoint, StringView(bufferDesc.Name), new Buffer(_context, cBufferDesc), true);
				}
			}
			reflection.Release();
		}
	}
}
