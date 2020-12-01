using System;
using DirectX.D3D11;
using System.Diagnostics;
using DirectX.Common;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
	public extension VertexLayout
	{
		internal ID3D11InputLayout* nativeLayout ~ _?.Release();

		public ID3DBlob* nativeShaderCode;

		public this(GraphicsContext context, VertexElement[] ownElements, ID3DBlob* nativeShaderCode)
		{
			this.nativeShaderCode = nativeShaderCode;

			_context = context;
			_elements = ownElements;

			CreateNativeLayout();
		}

		private void ToNativeLayout(VertexElement[] input, InputElementDescription[] output)
		{
			Debug.Assert(input.Count == output.Count);

			for(int i < input.Count)
				output[i] = .(input[i].SemanticName, input[i].SemanticIndex, input[i].Format, input[i].InputSlot, input[i].AlignedByteOffset, (.)input[i].InputSlotClass);
		}

		protected override void CreateNativeLayout()
		{
			var nativeElements = scope InputElementDescription[_elements.Count];

			ToNativeLayout(_elements, nativeElements);

			var result = _context.nativeDevice.CreateInputLayout(nativeElements.CArray(), (.)nativeElements.Count, nativeShaderCode.GetBufferPointer(), nativeShaderCode.GetBufferSize(), &nativeLayout);
			if(result.Failed)
			{
				Log.EngineLogger.Error($"Failed to create D3D11 input layout: Message({(int)result}): {result}");
			}
		}
	}
}
