using System;
using DirectX.D3D11;
using DirectX.Common;
using DirectXTK;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
	extension Texture2D
	{
		internal ID3D11Texture2D* nativeTexture ~ _?.Release();
		internal ID3D11ShaderResourceView* nativeView ~ _?.Release();
		internal Texture2DDescription nativeDesc;

		public override uint32 Width => nativeDesc.Width;
		public override uint32 Height => nativeDesc.Height;
		public override uint32 ArraySize => nativeDesc.ArraySize;
		public override uint32 MipLevels => nativeDesc.MipLevels;

		protected override void LoadTexturePlatform()
		{
			nativeTexture?.Release();
			nativeView?.Release();

			HResult loadResult = DDSTextureLoader.CreateDDSTextureFromFile(_context.nativeDevice, _path.ToScopedNativeWChar!(),
				(.)&nativeTexture, &nativeView);
			
			if(loadResult.Failed)
			{
				Log.EngineLogger.Error($"Failed to load texture \"{_path}\". Error({(int)loadResult}): {loadResult}");
				
				nativeTexture?.Release();
				nativeView?.Release();

				// TODO: load fallback texture
			}

			nativeTexture.GetDescription(out nativeDesc);
		}

		protected override void ImplBind(uint32 slot)
		{
			_context.nativeContext.VertexShader.SetShaderResources(slot, 1, &nativeView);
			_context.nativeContext.PixelShader.SetShaderResources(slot, 1, &nativeView);
		}
	}
}
