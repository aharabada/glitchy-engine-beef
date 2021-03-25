using System;
using DirectX.D3D11;
using DirectX.Common;
using DirectXTK;

using internal GlitchyEngine.Renderer;

typealias NativeTex2DDesc = DirectX.D3D11.Texture2DDescription;

namespace GlitchyEngine.Renderer
{
	extension Texture
	{
		protected internal ID3D11ShaderResourceView* nativeView ~ _?.Release();

		protected override void ImplBind(uint32 slot)
		{
			_context.nativeContext.VertexShader.SetShaderResources(slot, 1, &nativeView);
			_context.nativeContext.PixelShader.SetShaderResources(slot, 1, &nativeView);
		}
	}

	extension Texture2DDesc
	{
		public NativeTex2DDesc ToNative()
		{
			NativeTex2DDesc desc;

			desc.Width = Width;
			desc.Height = Height;
			desc.MipLevels = MipLevels;
			desc.ArraySize = ArraySize;
			desc.Format = Format;

			// TODO: missing options
			desc.SampleDesc = .(1, 0);
			desc.Usage = .Immutable;
			desc.BindFlags = .ShaderResource;
			desc.CpuAccessFlags = .None;
			desc.MiscFlags = .None;

			return desc;
		}

		public static implicit operator NativeTex2DDesc(Self desc) => desc.ToNative();
	}

	extension Texture2D
	{
		protected internal ID3D11Texture2D* nativeTexture ~ _?.Release();
		protected internal NativeTex2DDesc nativeDesc;

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

		protected override void CreateTexturePlatform(Texture2DDesc desc, void* data, uint32 linePitch)
		{
			nativeTexture?.Release();
			nativeView?.Release();

			nativeDesc = desc;
			SubresourceData resData = .(data, linePitch, 0);
			
			var result = _context.[Friend]nativeDevice.CreateTexture2D(ref nativeDesc, &resData, &nativeTexture);

			Log.EngineLogger.Assert(result.Succeeded, scope $"Failed to create texture 2D. Error ({result.Underlying}): {result}");

			result = _context.[Friend]nativeDevice.CreateShaderResourceView(nativeTexture, null, &nativeView);
			
			Log.EngineLogger.Assert(result.Succeeded, scope $"Failed to create texture view. Error ({result.Underlying}): {result}");
		}
	}
}
