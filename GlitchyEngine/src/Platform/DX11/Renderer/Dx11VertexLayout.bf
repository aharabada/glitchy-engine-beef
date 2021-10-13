#if GE_D3D11

using System;
using System.Diagnostics;
using DirectX.Common;
using DirectX.D3D11;
using GlitchyEngine.Platform.DX11;

using internal GlitchyEngine.Renderer;
using internal GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.Renderer
{
	public extension VertexLayout
	{
		internal ID3D11InputLayout* nativeLayout ~ _?.Release();

		public ID3DBlob* nativeShaderCode ~ _?.Release();

		public this(VertexElement[] elements, bool ownsElements, VertexShader vertexShader)
		{
			nativeShaderCode = vertexShader.nativeCode..AddRef();

			_elements = elements;
			_ownsElements = ownsElements;

			CreateNativeLayout();
		}

		private void ToNativeLayout(VertexElement[] input, InputElementDescription[] output)
		{
			Debug.Assert(input.Count == output.Count);

			for(int i < input.Count)
				output[i] = .(input[i].SemanticName, input[i].SemanticIndex, input[i].Format, input[i].InputSlot, input[i].AlignedByteOffset, (.)input[i].InputSlotClass, input[i].InstanceDataStepRate);
		}

		protected override void CreateNativeLayout()
		{
			var nativeElements = scope InputElementDescription[_elements.Count];

			ToNativeLayout(_elements, nativeElements);

			var result = NativeDevice.CreateInputLayout(nativeElements.CArray(), (.)nativeElements.Count, nativeShaderCode.GetBufferPointer(), nativeShaderCode.GetBufferSize(), &nativeLayout);
			if(result.Failed)
			{
				Log.EngineLogger.Error($"Failed to create D3D11 input layout: Message({(int)result}): {result}");
			}
		}
	}
}

#endif
