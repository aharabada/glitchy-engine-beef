#if GE_GRAPHICS_DX11

using System;
using DirectX.D3D11;
using DirectX.Common;
using DirectXTK;
using GlitchyEngine.Math;
using System.Collections;

using internal GlitchyEngine.Renderer;

typealias NativeTex2DDesc = DirectX.D3D11.Texture2DDescription;

using GlitchyEngine.Platform.DX11;
using internal GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.Renderer
{
	extension Texture
	{
		protected internal ID3D11ShaderResourceView* nativeResourceView ~ _?.Release();

		protected override void ImplBind(uint32 slot)
		{
			// TODO: textures don't bind themselves!
			NativeContext.VertexShader.SetShaderResources(slot, 1, &nativeResourceView);
			NativeContext.PixelShader.SetShaderResources(slot, 1, &nativeResourceView);
		}

		/** \brief Loads the texture from the specified path.
		 * @param path The path of the texture to load.
		 * @param texture The reference to the pointer that will hold the texture.
		 * @returns true if the texture was loaded successfully; false otherwise.
		 */
		protected bool LoadResourcePlatform<T>(StringView path, ref T* texture) where T : ID3D11Resource
		{
			((ID3D11Resource*)texture)?.Release();
			nativeResourceView?.Release();

			HResult loadResult = DDSTextureLoader.CreateDDSTextureFromFile(NativeDevice, path.ToScopedNativeWChar!(),
				(.)&texture, &nativeResourceView);

			if(loadResult.Failed)
			{
				Log.EngineLogger.Error($"Failed to load texture \"{path}\". Error({(int)loadResult}): {loadResult}");

				ReleaseAndNullify!(texture);
				ReleaseAndNullify!(nativeResourceView);

				return false;
			}

			return true;
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
			desc.Usage = (.)Usage;
			desc.BindFlags = .ShaderResource;

			desc.CpuAccessFlags = (.)CpuAccess;
			desc.MiscFlags = .None;

			return desc;
		}

		public static explicit operator NativeTex2DDesc(Self desc) => desc.ToNative();
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
			LoadResourcePlatform(_path, ref nativeTexture);

			let resType = nativeTexture.GetResourceType();
			Log.EngineLogger.Assert(resType == .Texture2D, scope $"The texture \"{_path}\" is not a 2D texture (it is {resType}).");

			nativeTexture.GetDescription(out nativeDesc);
		}

		protected override void CreateTexturePlatform(Texture2DDesc desc, bool isRenderTarget, void* data, uint32 linePitch)
		{
			PrepareTexturePlatform(desc, isRenderTarget);
			InternalCreateTexture(data, linePitch, 0);
		}

		private void InternalCreateTexture(void* data, uint32 linePitch, uint32 slicePitch)
		{
			SubresourceData resData = .(data, linePitch, slicePitch);

			// If data is null, set subresourceData null
			SubresourceData* resDataPtr = data == null ? null : &resData;

			var result = NativeDevice.CreateTexture2D(ref nativeDesc, resDataPtr, &nativeTexture);
			Log.EngineLogger.Assert(result.Succeeded, scope $"Failed to create texture 2D. Error ({result.Underlying}): {result}");

			result = NativeDevice.CreateShaderResourceView(nativeTexture, null, &nativeResourceView);
			Log.EngineLogger.Assert(result.Succeeded, scope $"Failed to create texture view. Error ({result.Underlying}): {result}");
		}

		protected override void PrepareTexturePlatform(Texture2DDesc desc, bool isRenderTarget)
		{
			nativeTexture?.Release();
			nativeTexture = null;
			nativeResourceView?.Release();
			nativeResourceView = null;

			nativeDesc = (NativeTex2DDesc)desc;

			if(isRenderTarget)
				nativeDesc.BindFlags |= .RenderTarget;
		}

		// TODO: Update Texture Arrays!
		protected override System.Result<void> PlatformSetData(void* data, uint32 elementSize, uint32 destX,
			uint32 destY, uint32 destWidth, uint32 destHeight, uint32 arraySlice, uint32 mipLevel, GlitchyEngine.Renderer.MapType mapType)
		{
			if(nativeTexture == null)
			{
				if(destX == 0 && destY == 0 && destWidth == nativeDesc.Width && destHeight == nativeDesc.Height)
				{
					// We can pass the data while creating the buffer, so we can return here.
					var rowPitch = elementSize * destWidth;
					return InternalCreateTexture(data, rowPitch, rowPitch * destHeight);
				}
				else
				{
					// If we don't set the entire texture we need to create the texture with unknown content and set it manually
					Log.EngineLogger.Assert(nativeDesc.Usage != .Immutable, "The entire immutable texture has to be initialized.");
					InternalCreateTexture(null, 0, 0);
				}
			}

			//Log.EngineLogger.AssertDebug();
			// TODO: Debug.Assert(dstByteOffset + byteLength <= _description.Size, "The destination offset and byte length are too long for the target buffer.");

			uint32 subresourceIndex = D3D11.CalcSubresource(mipLevel, arraySlice, nativeDesc.MipLevels);

			switch(nativeDesc.Usage)
			{
			case .Default:
				Box dataBox = .(destX, destY, 0, destX + destWidth, destY + destHeight, 1);
				var rowPitch = elementSize * destWidth;
				NativeContext.UpdateSubresource(nativeTexture, subresourceIndex, &dataBox, data, rowPitch, rowPitch * destHeight);
			case .Dynamic:
				Runtime.NotImplemented();
				/*
				Log.EngineLogger.Assert(mapType.CanWrite, "The map type has to have write access.");
				// Todo: DoNotWaitFlag
				MappedSubresource map = ?;
				_context.nativeContext.Map(nativeBuffer, 0, (.)mapType, .None, &map);
				Internal.MemCpy(((uint8*)map.Data) + dstByteOffset, data, byteLength);
				_context.nativeContext.Unmap(nativeBuffer, 0);
				*/
			case .Immutable:
				Log.EngineLogger.Error("Can't set the data of an immutable resource.");
				return .Err;
			default:
				Log.EngineLogger.Error($"Unknown resource usage: {nativeDesc.Usage}");
				return .Err;
			}

			return .Ok;
		}

		public static override void CopySubresourceRegion(Texture2D source, Texture2D destination,
			ResourceBox sourceBox = default, uint32 destX = 0, uint32 destY = 0,
			uint32 srcArraySlice = 0, uint32 srcMipSlice = 0, uint32 destArraySlice = 0, uint32 destMipSlice = 0)
		{
			Log.EngineLogger.AssertDebug(source != destination || srcArraySlice != destArraySlice
				|| srcMipSlice != destMipSlice, "Cannot copy from and to the same sub resource.");

			Log.EngineLogger.AssertDebug(source.nativeDesc.Format == destination.nativeDesc.Format,
				"Source and destination resources must have the same texel-format.");

			var sourceBox;

			if(sourceBox.Right == 0)
			{
				sourceBox.Right = source.Width;
				sourceBox.Bottom = source.Height;
				sourceBox.Back = 1;
			}

			// Make sure the destination was initialized
			if(destination.nativeTexture == null)
				destination.InternalCreateTexture(null, 0, 0);

			NativeContext.CopySubresourceRegion(destination.nativeTexture,
				D3D11.CalcSubresource(destMipSlice, destArraySlice, destination.MipLevels), destX, destY, 0,
				source.nativeTexture, D3D11.CalcSubresource(srcMipSlice, srcArraySlice, source.MipLevels), (.)&sourceBox); 
		}

		public override void CopyTo(Texture2D destination)
		{
			if(nativeTexture == null)
				return;

			Log.EngineLogger.AssertDebug(nativeDesc.Format == destination.nativeDesc.Format,
				"Source and destination resources must have the same texel-format.");
			
			// Make sure the destination was initialized
			if(destination.nativeTexture == null)
				destination.InternalCreateTexture(null, 0, 0);

			uint32 arraySlices = Math.Min(ArraySize, destination.ArraySize);
			uint32 mipSlices = Math.Min(MipLevels, destination.MipLevels);

			for(uint32 arraySlice < arraySlices)
			for(uint32 mipSlice < mipSlices)
			{
				Box sourceBox = .(0, 0, 0, Width, Height, 1);

				NativeContext.CopySubresourceRegion(destination.nativeTexture,
					D3D11.CalcSubresource(mipSlice, arraySlice, destination.MipLevels), 0, 0, 0,
					nativeTexture, D3D11.CalcSubresource(mipSlice, arraySlice, MipLevels), (.)&sourceBox);
			}
		}
	}

	extension TextureCube
	{
		protected internal ID3D11Texture2D* nativeTexture ~ _?.Release();
		protected internal NativeTex2DDesc nativeDesc;
		
		public override uint32 Width => nativeDesc.Width;
		public override uint32 Height => nativeDesc.Height;
		public override uint32 ArraySize => nativeDesc.ArraySize / 6;
		public override uint32 MipLevels => nativeDesc.MipLevels;

		protected override void LoadTexturePlatform()
		{
			LoadResourcePlatform(_path, ref nativeTexture);

			let resType = nativeTexture.GetResourceType();
			Log.EngineLogger.Assert(resType == .Texture2D, scope $"The texture \"{_path}\" is not a texture cube (it is {resType}).");

			nativeTexture.GetDescription(out nativeDesc);

			Log.EngineLogger.Assert(nativeDesc.MiscFlags.HasFlag(.TextureCube), scope $"The texture \"{_path}\" is not a texture cube.");
			// TODO: load fallback texture
		}
	}
}

#endif
