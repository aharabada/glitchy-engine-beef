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
		/**
		 * Internal compiled code of the shader.
		 */
		internal ID3DBlob* nativeCode ~ _?.Release();
		
		protected const ShaderCompileFlags DefaultCompileFlags = .EnableStrictness | 
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

			uint32 resourceCount = desc.BoundResources;
			for (uint32 i < resourceCount)
			{
				var res = reflection.GetResourceBindingDescription(i, let bindDesc);

				if (res.Failed)
				{
					Log.EngineLogger.Error($"Error({(int)res}) {res}: Failed to get resource binding desc for resource {i}");
					continue;
				}

				switch(bindDesc.Type)
				{
				case .ConstantBuffer:
					var bufferReflection = reflection.GetConstantBufferByName(bindDesc.Name);

					bufferReflection.GetDescription(let bufferDesc);

					// ConstantBuffer
					if(bufferDesc.Type == .D3D11_CT_CBUFFER)
					{
						let buffer = new ConstantBuffer(_context, bufferReflection);

						_buffers.Add(bindDesc.BindPoint, buffer.Name, buffer);

						buffer.ReleaseRef();
					}
				case .Texture:
					_textures.Add(scope String(bindDesc.Name), bindDesc.BindPoint, null);
				case .Sampler:
					// TODO: do we have to do something for samplers?
				default:
					Log.EngineLogger.Warning($"Unhandled shader resource type: \"{bindDesc.Type}\"");
				}
			}
			
			reflection.Release();
		}
	}
}
