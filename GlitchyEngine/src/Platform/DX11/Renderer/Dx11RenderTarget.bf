#if GE_GRAPHICS_DX11

using DirectX.Common;
using DirectX.D3D11;
using GlitchyEngine.Platform.DX11;
using DirectX.DXGI.DXGI1_2;
using System;
using GlitchyEngine.Math;

using internal GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.Renderer
{
	using internal GlitchyEngine.Renderer;

	extension RenderTarget2D
	{
		protected internal ID3D11Texture2D* _nativeTexture ~ _?.Release();
		protected internal ID3D11RenderTargetView* _nativeRenderTargetView ~ _?.Release();

		private void ReleaseAndNullify()
		{
			Debug.Profiler.ProfileResourceFunction!();

			ReleaseAndNullify!(_nativeTexture);
			ReleaseAndNullify!(_nativeResourceView);
			ReleaseAndNullify!(_nativeRenderTargetView);

			ReleaseRefAndNullify!(_depthStenilTarget);
		}

		public override void Resize(uint32 width, uint32 height)
		{
			Debug.Profiler.ProfileResourceFunction!();

			ReleaseAndNullify();

			_description.Width = width;
			_description.Height = height;

			ApplyChanges();
		}

		protected override void PlatformApplyChanges()
		{
			Debug.Profiler.ProfileResourceFunction!();

			ReleaseAndNullify();

			if(_description.IsSwapchainTarget)
			{
				// TODO: if the engine supports multiple windows it has to support multiple swap chains.

				// kinda dirty...
				var context = GraphicsContext.Get();

				context.SwapChain.GetBackbuffer(out _nativeTexture);

				CreateViews();
			}
			else
			{
				PlatformCreateTexture();
			}

			if(_description.DepthStencilFormat != .None)
			{
				_depthStenilTarget = new DepthStencilTarget(_description.Width, _description.Height, _description.DepthStencilFormat);
			}
		}

		private void PlatformCreateTexture()
		{
			Debug.Profiler.ProfileResourceFunction!();

			Texture2DDescription desc = .()
			{
				Width = _description.Width,
				Height = _description.Height,
				ArraySize = _description.ArraySize,
				MipLevels = _description.MipLevels,
				Format = _description.PixelFormat,
				// Always bindable as ShaderResource and RenderTarget
				BindFlags = .ShaderResource | .RenderTarget,
				CpuAccessFlags = (.)_description.CpuAccess,
				// 2D RenderTarget never has misc flags
				MiscFlags = .None,
				SampleDesc = .(_description.SampleCount, _description.SampleQuality),
				// RenderTarget has always Default usage
				Usage = .Default
			};

			var result = NativeDevice.CreateTexture2D(ref desc, null, &_nativeTexture);
			Log.EngineLogger.Assert(result.Succeeded, "Failed to create RenderTarget2D");

			CreateViews();
		}

		private void CreateViews()
		{
			Debug.Profiler.ProfileResourceFunction!();
			
			if(_description.IsSwapchainTarget)
			{
				var result = NativeDevice.CreateShaderResourceView(_nativeTexture, null, &_nativeResourceView);
				Log.EngineLogger.Assert(result.Succeeded, "Failed to create resource view");

				// TODO: SRGB...
				//RenderTargetViewDescription rtvDesc = .(_nativeTexture, .Texture2D, .R8G8B8A8_UNorm_SRGB);
				//result = NativeDevice.CreateRenderTargetView(_nativeTexture, &rtvDesc, &_nativeRenderTargetView);
				result = NativeDevice.CreateRenderTargetView(_nativeTexture, null, &_nativeRenderTargetView);
				Log.EngineLogger.Assert(result.Succeeded, "Failed to create render target view");
			}
			else
			{
				var result = NativeDevice.CreateShaderResourceView(_nativeTexture, null, &_nativeResourceView);
				Log.EngineLogger.Assert(result.Succeeded, "Failed to create resource view");

				result = NativeDevice.CreateRenderTargetView(_nativeTexture, null, &_nativeRenderTargetView);
				Log.EngineLogger.Assert(result.Succeeded, "Failed to create render target view");
			}
		}

		protected override TextureViewBinding PlatformGetViewBinding()
		{
			return .(_nativeResourceView, _samplerState.nativeSamplerState);
		}
	}

	extension RenderTargetFormat
	{
		public DirectX.DXGI.Format GetTextureFormat()
		{
			switch(this)
			{
			case .R8_SInt:
				return .R8_SInt;
			case .R32_UInt:
				return .R32_UInt;

			case .R8G8B8A8_UNorm:
				return .R8G8B8A8_UNorm;
			case .R8G8B8A8_SNorm:
				return .R8G8B8A8_SNorm;
				
			case .R16G16B16A16_SNorm:
				return .R16G16B16A16_SNorm;
			case .R16G16B16A16_Float:
				return .R16G16B16A16_Float;

			case .R32G32B32A32_Float:
				return .R32G32B32A32_Float;

			case .D24_UNorm_S8_UInt:
				return .R24G8_Typeless;

			default:
				return .Unknown;
			}
		}
		
		public DirectX.DXGI.Format GetShaderViewFormat()
		{
			switch(this)
			{
			case .D24_UNorm_S8_UInt:
				return .R24_UNorm_X8_Typeless;

			default:
				return GetTextureFormat();
			}
		}

		public DirectX.DXGI.Format GetTargetViewFormat()
		{
			switch(this)
			{
			case .D24_UNorm_S8_UInt:
				return .D24_UNorm_S8_UInt;

			default:
				return GetTextureFormat();
			}
		}
	}

	extension RenderTargetGroup
	{
		protected uint32 _mipLevels;
		internal ID3D11Texture2D*[] _nativeTextures;
		internal ID3D11RenderTargetView*[] _renderTargetViews;
		internal ID3D11ShaderResourceView*[] _nativeResourceViews;

		internal ID3D11Texture2D* _nativeDepthTexture;
		internal ID3D11DepthStencilView* _nativeDepthTargetView;
		internal ID3D11ShaderResourceView* _nativeDepthResourceView;

		~this()
		{
			ReleaseEveryThing();
		}

		internal ID3D11Texture2D* GetNativeTexture(int index)
		{
			Log.EngineLogger.AssertDebug(index >= -1 && index < ColorTargetCount);

			if (index == -1)
				return _nativeDepthTexture;

			return _nativeTextures[index];
		}

		private ID3D11Texture2D* PlatformCreateTexture(TargetDescription target)
		{
			Debug.Profiler.ProfileResourceFunction!();

			Texture2DDescription desc = .()
			{
				Width = _description.Width,
				Height = _description.Height,
				ArraySize = _description.ArraySize,
				MipLevels = _description.MipLevels,
				Format = target.Format.GetTextureFormat(),
				// Always bindable as ShaderResource and RenderTarget
				BindFlags = .ShaderResource | (target.Format.IsDepth ? .DepthStencil : .RenderTarget),
				// TODO: CpuAccessFlags = (.)_description.CpuAccess,
				//CpuAccessFlags = (.)_description.CpuAccess,
				// 2D RenderTarget never has misc flags
				MiscFlags = .None,
				SampleDesc = .(_description.Samples, 0), // TODO: SampleQuality?
				// RenderTarget always has Default usage
				Usage = .Default
			};

			ID3D11Texture2D* texture = null;
			var result = NativeDevice.CreateTexture2D(ref desc, null, &texture);
			Log.EngineLogger.Assert(result.Succeeded, "Failed to create RenderTarget2D");

			// TODO: calculate the max mip level
			// Read back the description to get the actual mip level count.
			texture.GetDescription(let actualDesc);
			_mipLevels = actualDesc.MipLevels;

			return texture;
		}

		private (ID3D11ShaderResourceView* ResourceView, ID3D11DeviceChild* TargetOrDepthView) CreateViews(TargetDescription target, ID3D11Texture2D* texture)
		{
			Debug.Profiler.ProfileResourceFunction!();
			
			ShaderResourceViewDescription svDesc = .();
			RenderTargetViewDescription rtDesc = .();
			DepthStencilViewDescription dsDesc = .();

			svDesc.Format = target.Format.GetShaderViewFormat();
			rtDesc.Format = target.Format.GetTargetViewFormat();
			dsDesc.Format = target.Format.GetTargetViewFormat();

			if (_description.ArraySize > 1)
			{
				if (_description.Samples > 1)
				{
					svDesc.ViewDimension = .Texture2DMultisampledArray;
					rtDesc.ViewDimension = .Texture2DArrayMultisample;
					dsDesc.ViewDimension = .Texture2DMultisampledArray;
				}
				else
				{
					svDesc.ViewDimension = .Texture2DArray;
					rtDesc.ViewDimension = .Texture2DArray;
					dsDesc.ViewDimension = .Texture2DArray;
				}
			}
			else
			{
				if (_description.Samples > 1)
				{
					svDesc.ViewDimension = .Texture2DMultisampled;
					rtDesc.ViewDimension = .Texture2DMultisample;
					dsDesc.ViewDimension = .Texture2DMultisampled;
				}
				else
				{
					svDesc.ViewDimension = .Texture2D;
					rtDesc.ViewDimension = .Texture2D;
					dsDesc.ViewDimension = .Texture2D;
				}
			}

			svDesc.Description = .(svDesc.ViewDimension);
			rtDesc.Description = .(rtDesc.ViewDimension);
			dsDesc.Description = .(dsDesc.ViewDimension);

			ID3D11ShaderResourceView* resourceView = null;
			ID3D11DeviceChild* targetOrDepthView = null;

			var result = NativeDevice.CreateShaderResourceView(texture, &svDesc, &resourceView);
			Log.EngineLogger.Assert(result.Succeeded, "Failed to create resource view");

			if (target.Format.IsDepth)
				result = NativeDevice.CreateDepthStencilView(texture, &dsDesc, (.)&targetOrDepthView);
			else
				result = NativeDevice.CreateRenderTargetView(texture, &rtDesc, (.)&targetOrDepthView);
			
			Log.EngineLogger.Assert(result.Succeeded, "Failed to create render target view");

			// TODO: UAVs

			return (resourceView, targetOrDepthView);
		}

		mixin DeleteContainerReleaseItemsAndNullify(var container)
		{
			if (container != null)
			{
				for (var tex in container)
				{
					tex.Release();
				}
				DeleteAndNullify!(container);
			}
		}

		private void ReleaseEveryThing()
		{
			DeleteContainerReleaseItemsAndNullify!(_nativeTextures);
			DeleteContainerReleaseItemsAndNullify!(_renderTargetViews);
			DeleteContainerReleaseItemsAndNullify!(_nativeResourceViews);

			ReleaseAndNullify!(_nativeDepthTexture);
			ReleaseAndNullify!(_nativeDepthTargetView);
			ReleaseAndNullify!(_nativeDepthResourceView);
		}

		public override void ApplyChanges()
		{
			Debug.Profiler.ProfileResourceFunction!();

			ReleaseEveryThing();

			if (_colorTargetDescriptions != null)
			{
				_nativeTextures = new .[_colorTargetDescriptions.Count];
				_renderTargetViews = new .[_colorTargetDescriptions.Count];
				_nativeResourceViews = new .[_colorTargetDescriptions.Count];
	
				for (int i < _nativeTextures.Count)
				{
					TargetDescription target = _colorTargetDescriptions[i];
	
					if (target.IsSwapchainTarget)
					{
						// TODO: if the engine supports multiple windows it has to support multiple swap chains.
		
						// kinda dirty...
						var context = GraphicsContext.Get();
		
						context.SwapChain.GetBackbuffer(out _nativeTextures[i]);
					}
					else
					{
						_nativeTextures[i] = PlatformCreateTexture(target);
					}
	
					(_nativeResourceViews[i], _renderTargetViews[i]) = (.)CreateViews(target, _nativeTextures[i]);
				}
			}
			
			if (_depthTargetDescription.Format != .None)
			{
				_nativeDepthTexture = PlatformCreateTexture(_depthTargetDescription);
				
				(_nativeDepthResourceView, _nativeDepthTargetView) = (.)CreateViews(_depthTargetDescription, _nativeDepthTexture);
			}
		}

		public override void Resize(uint32 width, uint32 height)
		{
			Debug.Profiler.ProfileResourceFunction!();

			_description.Width = width;
			_description.Height = height;

			ApplyChanges();
		}

		protected override TextureViewBinding PlatformGetViewBinding(int index)
		{
			if (index == -1)
			{
				return .(_nativeDepthResourceView, _depthSamplerState.nativeSamplerState);
			}
			else
			{
				Log.EngineLogger.AssertDebug(index < _nativeResourceViews.Count);

				return .(_nativeResourceViews[index], _colorSamplerStates[index].nativeSamplerState);
			}
		}

		protected override Result<void> PlatformGetData(void* destination, uint32 elementSize, uint32 x, uint32 y, uint32 width, uint32 height, int renderTarget, uint32 arraySlice, uint32 mipLevel) // mapType?
		{
			Debug.Profiler.ProfileResourceFunction!();

			ID3D11Texture2D* texture = renderTarget == -1 ? _nativeDepthTexture : _nativeTextures[renderTarget];

			if (texture == null)
				return .Err;

			// TODO: Dynamic textures with CPU read access don't need a staging texture.

			ID3D11Texture2D* stagingTexture = null;

			Texture2DDescription stagingDesc = .();
			stagingDesc.Width = width;
			stagingDesc.Height = height;
			stagingDesc.MipLevels = 1;
			stagingDesc.ArraySize = 1;
			stagingDesc.Format = _colorTargetDescriptions[renderTarget].Format.GetTextureFormat();
			stagingDesc.SampleDesc = .(_description.Samples, 0);
			stagingDesc.Usage = .Staging;
			stagingDesc.BindFlags = .None;
			stagingDesc.CpuAccessFlags = .Read;
			stagingDesc.MiscFlags = .None;

			var result = NativeDevice.CreateTexture2D(ref stagingDesc, null, &stagingTexture);
			if (result != 0)
				return .Err;

			defer stagingTexture.Release();
			
			uint32 srcSubResource = D3D11.CalcSubresource(mipLevel, arraySlice, _mipLevels);

			Box srcBox = .(x, y, arraySlice, x + width, y + height, arraySlice + 1);

			NativeContext.CopySubresourceRegion(stagingTexture, 0, 0, 0, 0, texture, srcSubResource, &srcBox);
			
			MappedSubresource subresource = ?;
			result = NativeContext.Map(stagingTexture, 0, .Read, .None, &subresource);
			defer NativeContext.Unmap(stagingTexture, 0);

			if (result != 0)
				return .Err;

			for (int i < height)
			{
				uint32 destRowLength = elementSize * width;

				uint32 count = Math.Min(destRowLength, subresource.RowPitch);

				Internal.MemCpy((uint8*)destination + i * destRowLength, (uint8*)subresource.Data + i * subresource.RowPitch,
					count);
			}

			return .Ok;
		}

		public override void CopyTo(RenderTargetGroup destination, int dstTarget, Int2 dstTopLeft, Int2 size, Int2 srcTopLeft, int srcTarget)
		{
			ID3D11Texture2D* dstTexture = destination.GetNativeTexture(dstTarget);
			ID3D11Texture2D* srcTexture = GetNativeTexture(srcTarget);

			// TODO: Mips/Arrays

			Box srcBox = .((.)srcTopLeft.X, (.)srcTopLeft.Y, 0, (.)(srcTopLeft.X + size.X), (.)(srcTopLeft.Y + size.Y), 1);

			NativeContext.CopySubresourceRegion(dstTexture, 0, (.)dstTopLeft.X, (.)dstTopLeft.Y, 0, srcTexture, 0, &srcBox);
		}
	}
}

#endif
