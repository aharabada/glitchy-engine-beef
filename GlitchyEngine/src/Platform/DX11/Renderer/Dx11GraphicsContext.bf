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

		// current vertex layout and vertex shader needed for validation.
		ID3D11InputLayout* _currentInputLayout ~ _?.Release();
		VertexLayout _currentVertexLayout ~ _?.ReleaseRef();
		VertexShader _currentVertexShader ~ _?.ReleaseRef();

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

		internal void SetNativeDepthStencilTarget(ID3D11DepthStencilView* depthStencilTarget)
		{
			_depthStencilTarget = depthStencilTarget;
		}

		public override void SetRenderTarget(RenderTarget2D renderTarget, int slot, bool setDepthTarget)
		{
			_renderTargets[slot] = (renderTarget ?? _swapChain.BackBuffer)._nativeRenderTargetView;

			if(slot == 0 && setDepthTarget)
			{
				SetDepthStencilTarget((renderTarget ?? _swapChain.BackBuffer).DepthStencilTarget);
			}
		}

		internal void SetNativeRenderTargets(Span<ID3D11RenderTargetView*> renderTargets, int startSlot)
		{
			for (int i < renderTargets.Length)
			{
				_renderTargets[i + startSlot] = renderTargets[i];
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
			using (ContextMonitor.Enter())
			{
				NativeContext.OutputMerger.SetRenderTargets(MaxRTVCount, &_renderTargets, _depthStencilTarget);
			}
		}

		public override void ClearRenderTarget(RenderTarget2D renderTarget, ColorRGBA color)
		{
			using (ContextMonitor.Enter())
			{
				NativeContext.ClearRenderTargetView((renderTarget ?? _swapChain.BackBuffer)._nativeRenderTargetView, color);
			}
		}

		public override void SetVertexBuffer(uint32 slot, Buffer buffer, uint32 stride, uint32 offset = 0)
		{
			// make stride and offset mutable so that we can take their pointers.
			var stride, offset;
			using (ContextMonitor.Enter())
			{
				NativeContext.InputAssembler.SetVertexBuffers(slot, 1, &buffer.nativeBuffer, &stride, &offset);
			}
		}

		[Inline]
		private void BindInputLayout()
		{
			if (_currentInputLayout == null)
			{
				ID3D11InputLayout* newInputLayout = _currentVertexLayout.GetNativeVertexLayout(_currentVertexShader);

				if (newInputLayout == _currentInputLayout)
					return;

				_currentInputLayout?.Release();
				_currentInputLayout = newInputLayout;
				_currentInputLayout.AddRef();
				
				using (ContextMonitor.Enter())
				{
					NativeContext.InputAssembler.SetInputLayout(_currentInputLayout);
				}
			}
		}

		private void BindState()
		{
			Debug.Profiler.ProfileRendererFunction!();
			
			BindInputLayout();
			
			if (_hasVs)
			{
				NativeContext.VertexShader.SetShaderResources(0, _vsShaderResources.Count, &_vsShaderResources);
				NativeContext.VertexShader.SetSamplers(0, _vsSamplers.Count, &_vsSamplers);
				NativeContext.VertexShader.SetConstantBuffers(0, _vsBuffers.Count, &_vsBuffers);
			}

			if (_hasPs)
			{
				NativeContext.PixelShader.SetShaderResources(0, _psShaderResources.Count, &_psShaderResources);
				NativeContext.PixelShader.SetSamplers(0, _psSamplers.Count, &_psSamplers);
				NativeContext.PixelShader.SetConstantBuffers(0, _psBuffers.Count, &_psBuffers);
			}
		}

		public override void Draw(uint32 vertexCount, uint32 startVertexIndex = 0)
		{
			using (ContextMonitor.Enter())
			{
				BindState();
	
				NativeContext.Draw(vertexCount, startVertexIndex);
			}
		}

		public override void DrawIndexed(uint32 indexCount, uint32 startIndexLocation = 0, int32 vertexOffset = 0)
		{
			using (ContextMonitor.Enter())
			{
				BindState();
	
				NativeContext.DrawIndexed(indexCount, startIndexLocation, vertexOffset);
			}
		}

		public override void DrawIndexedInstanced(uint32 indexCountPerInstance, uint32 instanceCount, uint32 startIndexLocation, int32 baseVertexLocation, uint32 startInstanceLocation)
		{
			using (ContextMonitor.Enter())
			{
				BindState();
	
				NativeContext.DrawIndexedInstanced(indexCountPerInstance, instanceCount, startIndexLocation, baseVertexLocation, startInstanceLocation);
			}
		}

		public override void SetIndexBuffer(Buffer buffer, IndexFormat indexFormat = .Index16Bit, uint32 byteOffset = 0)
		{
			using (ContextMonitor.Enter())
			{
				NativeContext.InputAssembler.SetIndexBuffer(buffer.nativeBuffer, indexFormat == .Index32Bit ? .R32_UInt : .R16_UInt, byteOffset);
			}
		}

		public override void SetViewports(uint32 viewportsCount, GlitchyEngine.Renderer.Viewport* viewports)
		{
			using (ContextMonitor.Enter())
			{
				NativeContext.Rasterizer.SetViewports(viewportsCount, (.)viewports);
			}
		}

		public override void SetVertexLayout(VertexLayout vertexLayout)
		{
			if (_currentVertexLayout != vertexLayout)
			{
				SetReference!(_currentVertexLayout, vertexLayout);
				_currentInputLayout?.Release();
				_currentInputLayout = null;
			}
		}

		public override void SetPrimitiveTopology(GlitchyEngine.Renderer.PrimitiveTopology primitiveTopology)
		{
			using (ContextMonitor.Enter())
			{
				NativeContext.InputAssembler.SetPrimitiveTopology((DirectX.Common.PrimitiveTopology)primitiveTopology);
			}
		}

		private uint32 _ps_FirstTexture;
		private uint32 _ps_BoundTextures;
		private uint32 _vs_FirstTexture;
		private uint32 _vs_BoundTextures;

		private bool _hasPs;
		private bool _hasVs;

		private ID3D11Buffer*[DirectX.D3D11.D3D11_COMMONSHADER_CONSTANT_BUFFER_API_SLOT_COUNT] _vsBuffers;
		private ID3D11Buffer*[DirectX.D3D11.D3D11_COMMONSHADER_CONSTANT_BUFFER_API_SLOT_COUNT] _psBuffers;

		private ID3D11ShaderResourceView*[DirectX.D3D11.D3D11_COMMONSHADER_SAMPLER_SLOT_COUNT] _vsShaderResources;
		private ID3D11SamplerState*[DirectX.D3D11.D3D11_COMMONSHADER_SAMPLER_SLOT_COUNT] _vsSamplers;
		private ID3D11ShaderResourceView*[DirectX.D3D11.D3D11_COMMONSHADER_SAMPLER_SLOT_COUNT] _psShaderResources;
		private ID3D11SamplerState*[DirectX.D3D11.D3D11_COMMONSHADER_SAMPLER_SLOT_COUNT] _psSamplers;

		/**
		 * Binds the given shader to the corresponding shader stage.
		 * @param shader The shader that will be bound to the graphics context.
		 */
		private void BindShaderToStage<TShader>(TShader shader) where TShader : Shader
		{
			Debug.Profiler.ProfileRendererFunction!();

			//uint32 _firstTexture = D3D11_COMMONSHADER_INPUT_RESOURCE_SLOT_COUNT;
			//uint32 _textureCount = 0;

			ID3D11ShaderResourceView*[D3D11_COMMONSHADER_SAMPLER_SLOT_COUNT] shaderResources = .();
			ID3D11SamplerState*[D3D11_COMMONSHADER_SAMPLER_SLOT_COUNT] samplers = .();


			for (let entry in shader?.Textures)
			{
				shaderResources[entry.Index] = entry.BoundTexture._nativeShaderResourceView;
				samplers[entry.Index] = entry.BoundTexture._nativeSamplerState;
				
				/*if(entry.Index >= _textureCount)
					_textureCount = entry.Index + 1;
				if(entry.Index < _firstTexture)
					_firstTexture = entry.Index;*/
			}
			
			//constantBuffers.PlatformFetchNativeBuffers();

			switch (typeof(TShader))
			{
				// TODO: Add remaining shader stages
			case typeof(PixelShader):
				_hasPs = shader != null;

				// TODO: bind uavs
				/*if (_textureCount > 0)
				{
					//NativeContext.PixelShader.SetShaderResources(_firstTexture, _textureCount, &_textures[_firstTexture]);
					//NativeContext.PixelShader.SetSamplers(_firstTexture, _textureCount, &_samplers[_firstTexture]);
				}*/

				/*_ps_FirstTexture = _firstTexture;
				_ps_BoundTextures = _textureCount;*/

				//_psBuffers = constantBuffers.nativeBuffers;

				//NativeContext.PixelShader.SetConstantBuffers(0, shader.Buffers.nativeBuffers.Count, &shader.Buffers.nativeBuffers);

				_psShaderResources = shaderResources;
				_psSamplers = samplers;

				NativeContext.PixelShader.SetShader((ID3D11PixelShader*)shader?.nativeShader);

			case typeof(VertexShader):
				_hasVs = shader != null;

				/*if (_textureCount > 0)
				{
					NativeContext.VertexShader.SetShaderResources(_firstTexture, _textureCount, &_textures[_firstTexture]);
					NativeContext.VertexShader.SetSamplers(_firstTexture, _textureCount, &_samplers[_firstTexture]);
				}*/
				
				//_vsBuffers = constantBuffers.nativeBuffers;

				//NativeContext.VertexShader.SetConstantBuffers(0, shader.Buffers.nativeBuffers.Count, &shader.Buffers.nativeBuffers);
				
				_vsShaderResources = shaderResources;
				_vsSamplers = samplers;

				NativeContext.VertexShader.SetShader((ID3D11VertexShader*)shader?.nativeShader);

				/*_vs_FirstTexture = _firstTexture;
				_vs_BoundTextures = _textureCount;*/
				
				//if (VertexShader vs = shader as VertexShader)
				[ConstSkip]
				{
					SetReference!(_currentVertexShader, shader);
					_currentInputLayout?.Release();
					_currentInputLayout = null;
				}
			default:
				Runtime.FatalError(scope $"Shader stage \"{typeof(TShader)}\" not implemented.");
			}
		}

		public override void UnbindTextures()
		{
			_vsShaderResources = .();
			_psShaderResources = .();

			using (ContextMonitor.Enter())
			{
				// Do we need to set here, or is it enough to do it in BindState?
				NativeContext.PixelShader.SetShaderResources(0, D3D11_COMMONSHADER_SAMPLER_SLOT_COUNT, &_vsShaderResources);
				NativeContext.VertexShader.SetShaderResources(0, D3D11_COMMONSHADER_SAMPLER_SLOT_COUNT, &_psShaderResources);
			}
		}

		public override void BindVertexShader(VertexShader vertexShader)
		{
			using (ContextMonitor.Enter())
			{
				BindShaderToStage(vertexShader);
			}
		}

		public override void BindPixelShader(PixelShader pixelShader)
		{
			using (ContextMonitor.Enter())
			{
				BindShaderToStage(pixelShader);
			}
		}

		public override void BindConstantBuffer(Buffer buffer, int slot, ShaderStage stage)
		{
			Debug.Assert((slot >= 0) && (slot < DirectX.D3D11.D3D11_COMMONSHADER_CONSTANT_BUFFER_API_SLOT_COUNT));

			if (stage.HasFlag(.Vertex))
			{
				_vsBuffers[slot] = buffer.nativeBuffer;
			}
			
			if (stage.HasFlag(.Pixel))
			{
				_psBuffers[slot] = buffer.nativeBuffer;
			}
		}

		public override void BindTexture(TextureViewBinding textureBinding, int slot, ShaderStage shaderStage)
		{
			Debug.Assert((slot >= 0) && (slot < DirectX.D3D11.D3D11_COMMONSHADER_INPUT_RESOURCE_SLOT_COUNT));

			if (shaderStage.HasFlag(.Vertex))
			{
				_vsShaderResources[slot] = textureBinding?._nativeShaderResourceView;
				_vsSamplers[slot] = textureBinding?._nativeSamplerState;
			}
			
			if (shaderStage.HasFlag(.Pixel))
			{
				_psShaderResources[slot] = textureBinding?._nativeShaderResourceView;
				_psSamplers[slot] = textureBinding?._nativeSamplerState;
			}
		}

		public override void BindConstantBuffers(BufferCollection bufferCollection, ShaderStage shaderStage)
		{
			bufferCollection.PlatformFetchNativeBuffers();

			if (shaderStage.HasFlag(.Vertex))
				_vsBuffers = bufferCollection.nativeBuffers;
 
			if (shaderStage.HasFlag(.Pixel))
				_psBuffers = bufferCollection.nativeBuffers;
		}
	}
}

#endif
