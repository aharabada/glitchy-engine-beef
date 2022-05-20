using DirectX.D3D11;

namespace GlitchyEngine.Renderer
{
	extension TextureViewBinding
	{
		internal ID3D11ShaderResourceView* _nativeShaderResourceView;
		internal ID3D11SamplerState* _nativeSamplerState;
		
		public override bool IsEmpty => _nativeShaderResourceView != null;

		internal this(ID3D11ShaderResourceView* shaderResourceView, ID3D11SamplerState* samplerState)
		{
			_nativeShaderResourceView = shaderResourceView;
			_nativeShaderResourceView?.AddRef();

			_nativeSamplerState = samplerState;
			_nativeSamplerState?.AddRef();
		}

		public override void AddRef()
		{
			_nativeShaderResourceView?.AddRef();
			_nativeSamplerState?.AddRef();
		}

		public override void ReleaseRef()
		{
			_nativeShaderResourceView?.Release();
			_nativeSamplerState?.Release();
		}
	}
}
