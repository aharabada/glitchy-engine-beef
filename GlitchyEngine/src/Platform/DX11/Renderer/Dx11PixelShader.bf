using System;
using DirectX.D3D11;
using DirectX.D3DCompiler;
using DirectX.D3D11Shader;
using DirectX.Common;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
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
}
