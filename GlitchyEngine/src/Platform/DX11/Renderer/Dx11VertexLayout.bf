#if GE_GRAPHICS_DX11

using System;
using System.Diagnostics;
using DirectX.Common;
using DirectX.D3D11;
using GlitchyEngine.Platform.DX11;
using System.Collections;

using internal GlitchyEngine.Renderer;
using internal GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.Renderer
{
	public extension VertexLayout
	{
		// TODO: This will leak memory, when a shader reloads
		private Dictionary<VertexShader, ID3D11InputLayout*> _validatedShaders = new .() ~
			{
				if (_ != null)
				{
					for (let entry in _)
					{
						entry.key.ReleaseRef();
						entry.value.Release();
					}

					delete _;
				}
			};

		private void ToNativeLayout(VertexElement[] input, InputElementDescription[] output)
		{
			Debug.Assert(input.Count == output.Count);

			for(int i < input.Count)
				output[i] = .(input[i].SemanticName, input[i].SemanticIndex, (.)input[i].Format, input[i].InputSlot, input[i].AlignedByteOffset, (.)input[i].InputSlotClass, input[i].InstanceDataStepRate);
		}

		/// Validates or gets the validated input layout for the given vertexshader.
		internal ID3D11InputLayout* GetNativeVertexLayout(VertexShader vertexShader)
		{
			Debug.Profiler.ProfileResourceFunction!();

			ID3D11InputLayout* layout = null;

			if (!_validatedShaders.TryGetValue(vertexShader, out layout))
			{
				var nativeElements = scope InputElementDescription[_elements.Count];

				ToNativeLayout(_elements, nativeElements);

				var result = NativeDevice.CreateInputLayout(nativeElements.CArray(), (.)nativeElements.Count,
					vertexShader.nativeCode.GetBufferPointer(), vertexShader.nativeCode.GetBufferSize(), &layout);
				if(result.Failed)
				{
					Log.EngineLogger.Error($"Failed to create D3D11 input layout: Message({(int)result}): {result}");
					Debug.FatalError();
				}

				_validatedShaders[vertexShader..AddRef()] = layout;
			}

			return layout;
		}
	}
}

#endif
