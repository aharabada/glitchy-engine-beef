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

			// TODO: What is the 200 check for?
			if ((uint)(void*)_nativeShaderResourceView != 0 && (uint)(void*)_nativeShaderResourceView < 200)
			{

			}

			_nativeShaderResourceView?.AddRef();

			_nativeSamplerState = samplerState;
			_nativeSamplerState?.AddRef();
		}
		
		protected ~this()
		{
			_nativeShaderResourceView?.Release();
			_nativeSamplerState?.Release();
		}

		public static override TextureViewBinding CreateDefault() => new .(null, null);
	}
}
