#if GE_GRAPHICS_DX11

using System;
using System.IO;
using System.Collections;
using DirectX.Common;
using DirectX.D3D11;
using DirectX.D3D11Shader;
using DirectX.D3DCompiler;
using GlitchyEngine.Content;
using GlitchyEngine.Renderer;
using GlitchyEngine.Platform.DX11;

using internal GlitchyEngine.Renderer;
using internal GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.Renderer
{
	extension Shader
	{
		internal ID3D11DeviceChild* nativeShader ~ _?.Release();

		/**
		 * Internal compiled code of the shader.
		 */
		internal ID3DBlob* nativeCode ~ _?.Release();
		
		protected override Result<void> InternalCreateFromBlob(Span<uint8> blob)
		{
			HResult shaderCreationResult = HResult.S_FALSE;

			// TODO Temporary, because we need to generate the vertex layout from it!
			D3DCompiler.D3DCreateBlob((.)blob.Length, &nativeCode);
			Internal.MemCpy(nativeCode.GetBufferPointer(), blob.Ptr, blob.Length);

			switch (_shaderType)
			{
			case .Vertex:
				shaderCreationResult = NativeDevice.CreateVertexShader(blob.Ptr, (uint)blob.Length, null, (ID3D11VertexShader**)&nativeShader);
			case .Pixel:
				shaderCreationResult = NativeDevice.CreatePixelShader(blob.Ptr, (uint)blob.Length, null, (ID3D11PixelShader**)&nativeShader);
			default:
				Log.EngineLogger.Error($"Can't create native shader of type {_shaderType}.");
				return .Err;
			}

			if(shaderCreationResult.Failed)
			{
				Log.EngineLogger.Error($"Failed to create native shader from blob: {shaderCreationResult} ({(int)shaderCreationResult})");

				if (nativeShader != null)
				{
					nativeShader.Release();
				}

				return .Err;
			}

			return .Ok;
		}
	}
}

#endif
