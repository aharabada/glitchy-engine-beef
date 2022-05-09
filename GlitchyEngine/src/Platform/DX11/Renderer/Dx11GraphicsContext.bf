#if GE_GRAPHICS_DX11

using System;
using System.Diagnostics;
using DirectX.Common;
using DirectX.D3D11;
using DirectX.D3D11.SDKLayers;
using DirectX.DXGI.DXGI1_2;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using DirectX.D3D11.DeviceContextStages;
using internal GlitchyEngine.Renderer;

using GlitchyEngine.Platform.DX11;
using internal GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.Renderer
{
	/// DirectX 11 specific implementation of the GraphicsContext
	extension GraphicsContext
	{
		private SwapChain _swapChain;

		internal Windows.HWnd nativeWindowHandle;

		/// Gets whether or not the DX11 device is initialized.
		//internal bool IsDx11Initialized => nativeDevice != null;
		//internal ID3D11Device* nativeDevice => NativeDevice;
		//internal ID3D11DeviceContext* nativeContext => NativeContext;

		//internal ID3D11Debug* debugDevice => DebugDevice;

		public override SwapChain SwapChain => _swapChain;

		private const uint32 MaxRTVCount = DirectX.D3D11.D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT;

		//public static override uint32 MaxRenderTargetCount() => MaxRTVCount;

		public this(Windows.HWnd windowHandle)
		{
			Debug.Profiler.ProfileFunction!();

			nativeWindowHandle = windowHandle;

			_swapChain = new SwapChain(this);

			s_GraphicsContext = this;
		}

		public ~this()
		{
			Debug.Profiler.ProfileFunction!();

			delete _swapChain;

			Dx11Release();
		}

		public override void Init()
		{
			Debug.Profiler.ProfileFunction!();

			Dx11Init();

			SwapChain.Init();
		}

		/**
		 * Initializes the Device and ImmediateContext.
		 */
		/*
		void InitDevice()
		{
			if(!IsDx11Initialized)
			{
				Log.EngineLogger.Trace("Creating D3D11 Device and Context...");
				
				DeviceCreationFlags deviceFlags = .None;
#if DEBUG
				deviceFlags |= .Debug;
#endif

				FeatureLevel[] levels = scope .(.Level_11_0);

				FeatureLevel deviceLevel = ?;
				var deviceResult = D3D11.CreateDevice(null, .Hardware, 0, deviceFlags, levels, &nativeDevice, &deviceLevel, &nativeContext);
				Log.EngineLogger.Assert(deviceResult.Succeeded, scope $"Failed to create D3D11 Device. Message({(int32)deviceResult}): {deviceResult}");

#if DEBUG	
				if(nativeDevice.QueryInterface<ID3D11Debug>(out debugDevice).Succeeded)
				{
					ID3D11InfoQueue* infoQueue;
					if(nativeDevice.QueryInterface<ID3D11InfoQueue>(out infoQueue).Succeeded)
					{
						infoQueue.SetBreakOnSeverity(.Corruption, true);
						infoQueue.SetBreakOnSeverity(.Error, true);

						infoQueue.Release();
					}
				}
#endif

				Log.EngineLogger.Trace($"D3D11 Device and Context created (Feature level: {deviceLevel})");
			}
			else
			{
				// We created a second GraphicsContext (for some reason?) just increment references.
				nativeDevice.AddRef();
				nativeContext.AddRef();
				debugDevice.AddRef();
			}
		}
		*/

		private ID3D11DepthStencilView* _depthStencilTarget;
		private ID3D11RenderTargetView*[MaxRTVCount] _renderTargets;
		
		public override void SetDepthStencilTarget(DepthStencilTarget target)
		{
			_depthStencilTarget = target?.nativeView;
		}

		public override void SetRenderTarget(RenderTarget2D renderTarget, int slot, bool setDepthTarget)
		{
			_renderTargets[slot] = (renderTarget ?? _swapChain.BackBuffer)._nativeRenderTargetView;

			if(slot == 0 && setDepthTarget)
			{
				SetDepthStencilTarget((renderTarget ?? _swapChain.BackBuffer).DepthStencilTarget);
			}
		}
		
		public override void UnbindRenderTargets()
		{
			for (var rt in ref _renderTargets)
			{
				rt = null;
			}
		}

		public override void BindRenderTargets()
		{
			NativeContext.OutputMerger.SetRenderTargets(MaxRTVCount, &_renderTargets, _depthStencilTarget);
		}

		public override void ClearRenderTarget(RenderTarget2D renderTarget, ColorRGBA color)
		{
			NativeContext.ClearRenderTargetView((renderTarget ?? _swapChain.BackBuffer)._nativeRenderTargetView, color);
		}

		public override void SetVertexBuffer(uint32 slot, Buffer buffer, uint32 stride, uint32 offset = 0)
		{
			// make stride and offset mutable so that we can take their pointers.
			var stride, offset;
			NativeContext.InputAssembler.SetVertexBuffers(slot, 1, &buffer.nativeBuffer, &stride, &offset);
		}

		public override void Draw(uint32 vertexCount, uint32 startVertexIndex = 0)
		{
			NativeContext.Draw(vertexCount, startVertexIndex);
		}

		public override void DrawIndexed(uint32 indexCount, uint32 startIndexLocation = 0, int32 vertexOffset = 0)
		{
			NativeContext.DrawIndexed(indexCount, startIndexLocation, vertexOffset);
		}

		public override void SetIndexBuffer(Buffer buffer, IndexFormat indexFormat = .Index16Bit, uint32 byteOffset = 0)
		{
			NativeContext.InputAssembler.SetIndexBuffer(buffer.nativeBuffer, indexFormat == .Index32Bit ? .R32_UInt : .R16_UInt, byteOffset);
		}

		public override void SetViewports(uint32 viewportsCount, GlitchyEngine.Renderer.Viewport* viewports)
		{
			NativeContext.Rasterizer.SetViewports(viewportsCount, (.)viewports);
		}

		public override void SetVertexLayout(VertexLayout vertexLayout)
		{
			NativeContext.InputAssembler.SetInputLayout(vertexLayout.nativeLayout);
		}

		public override void SetPrimitiveTopology(GlitchyEngine.Renderer.PrimitiveTopology primitiveTopology)
		{
			NativeContext.InputAssembler.SetPrimitiveTopology((DirectX.Common.PrimitiveTopology)primitiveTopology);
		}

		private uint32 _ps_FirstTexture;
		private uint32 _ps_BoundTextures;
		private uint32 _vs_FirstTexture;
		private uint32 _vs_BoundTextures;

		/**
		 * Binds the given shader to the corresponding shader stage.
		 * @param shader The shader that will be bound to the graphics context.
		 */
		private void BindShaderToStage<TShader>(TShader shader) where TShader : Shader
		{
			Debug.Profiler.ProfileRendererFunction!();

			uint32 _firstTexture = D3D11_COMMONSHADER_INPUT_RESOURCE_SLOT_COUNT;
			uint32 _textureCount = 0;

			ID3D11ShaderResourceView*[D3D11_COMMONSHADER_INPUT_RESOURCE_SLOT_COUNT] _textures = .();
			ID3D11SamplerState*[D3D11_COMMONSHADER_INPUT_RESOURCE_SLOT_COUNT] _samplers = .();

			for(let entry in shader.Textures)
			{
				_textures[entry.Index] = entry.Texture?._nativeResourceView;
				_samplers[entry.Index] = entry.Texture?.SamplerState?.nativeSamplerState;
				
				if(entry.Index >= _textureCount)
					_textureCount = entry.Index + 1;
				if(entry.Index < _firstTexture)
					_firstTexture = entry.Index;
			}
			
			if(_textureCount > 0)
			{
				switch(typeof(TShader))
				{
					// TODO: Add remaining shader stages
				case typeof(PixelShader):
					// TODO: bind uavs
					NativeContext.PixelShader.SetShaderResources(_firstTexture, _textureCount, &_textures[_firstTexture]);
					NativeContext.PixelShader.SetSamplers(_firstTexture, _textureCount, &_samplers[_firstTexture]);

					_ps_FirstTexture = _firstTexture;
					_ps_BoundTextures = _textureCount;
				case typeof(VertexShader):
					NativeContext.VertexShader.SetShaderResources(_firstTexture, _textureCount, &_textures[_firstTexture]);
					NativeContext.VertexShader.SetSamplers(_firstTexture, _textureCount, &_samplers[_firstTexture]);
					
					_vs_FirstTexture = _firstTexture;
					_vs_BoundTextures = _textureCount;
				default:
					Runtime.FatalError(scope $"Shader stage \"{typeof(TShader)}\" not implemented.");
				}
			}
			
			shader.Buffers.PlatformFetchNativeBuffers();
			
			switch(typeof(TShader))
			{
				// TODO: Add remaining shader stages
			case typeof(PixelShader):
				NativeContext.PixelShader.SetConstantBuffers(0, shader.Buffers.nativeBuffers.Count, &shader.Buffers.nativeBuffers);
				[IgnoreErrors]{ NativeContext.PixelShader.SetShader(((PixelShader)shader).nativeShader); }
			case typeof(VertexShader):
				NativeContext.VertexShader.SetConstantBuffers(0, shader.Buffers.nativeBuffers.Count, &shader.Buffers.nativeBuffers);
				[IgnoreErrors]{ NativeContext.VertexShader.SetShader(((VertexShader)shader).nativeShader); }
			default:
				Runtime.FatalError(scope $"Shader stage \"{typeof(TShader)}\" not implemented.");
			}
		}

		public override void UnbindTextures()
		{
			void** voidArray = scope void*[D3D11_COMMONSHADER_INPUT_RESOURCE_SLOT_COUNT]*;

			NativeContext.PixelShader.SetShaderResources(0, D3D11_COMMONSHADER_INPUT_RESOURCE_SLOT_COUNT, (.)voidArray);
			NativeContext.VertexShader.SetShaderResources(0, D3D11_COMMONSHADER_INPUT_RESOURCE_SLOT_COUNT, (.)voidArray);
		}

		public override void SetVertexShader(VertexShader vertexShader)
		{
			BindShaderToStage(vertexShader);
		}

		public override void SetPixelShader(PixelShader pixelShader)
		{
			BindShaderToStage(pixelShader);
		}
	}
}

#endif
