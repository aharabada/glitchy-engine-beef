using System;
using System.Diagnostics;
using DirectX.Common;
using DirectX.D3D11;
using DirectX.D3D11.SDKLayers;
using DirectX.DXGI.DXGI1_2;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
	/// DirectX 11 specific implementation of the GraphicsContext
	extension GraphicsContext
	{
		private SwapChain _swapChain;

		internal Windows.HWnd nativeWindowHandle;

		internal ID3D11Device* nativeDevice;
		internal ID3D11DeviceContext* nativeContext;
		
		private ID3D11Debug* _debugDevice;

		public override SwapChain SwapChain => _swapChain;

		private const uint32 MaxRTVCount = DirectX.D3D11.D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT;

		//public static override uint32 MaxRenderTargetCount() => MaxRTVCount;

		public this(Windows.HWnd windowHandle)
		{
			nativeWindowHandle = windowHandle;

			_swapChain = new SwapChain(this);
		}

		public ~this()
		{
			delete _swapChain;

			nativeDevice?.Release();
			nativeContext?.Release();
			_debugDevice.ReportLiveDeviceObjects(.Detail);
			_debugDevice?.Release();
		}

		public override void Init()
		{
			InitDevice();

			SwapChain.Init();
		}

		/**
		 * Initializes the Device and ImmediateContext.
		 */
		void InitDevice()
		{
			nativeDevice?.Release();
			nativeContext?.Release();
			
			Log.EngineLogger.Trace("Creating D3D11 Device and Context...");

			DeviceCreationFlags deviceFlags = .None;
#if DEBUG
			deviceFlags |= .Debug;
#endif

			FeatureLevel[] levels = scope .(.Level_11_0);

			FeatureLevel deviceLevel = ?;
			var deviceResult = D3D11.CreateDevice(null, .Hardware, 0, deviceFlags, levels, &nativeDevice, &deviceLevel, &nativeContext);
			Debug.Assert(deviceResult.Succeeded, scope $"Failed to create D3D11 Device. Message(0x{(int32)deviceResult}): {deviceResult}");

#if DEBUG	
			if(nativeDevice.QueryInterface<ID3D11Debug>(out _debugDevice).Succeeded)
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

		
		
		private ID3D11DepthStencilView* _depthStencilTarget;
		private ID3D11RenderTargetView*[MaxRTVCount] _renderTargets;
		
		internal void SetDepthStencilTarget(DepthStencilTarget target)
		{
			_depthStencilTarget = target?.nativeView;
		}

		public override void SetRenderTarget(RenderTarget renderTarget, int slot = 0)
		{
			if(renderTarget == null)
			{
				_renderTargets[slot] = _swapChain.nativeBackBufferTarget;
			}
			else
			{
				Runtime.NotImplemented();
			}
		}

		public override void BindRenderTargets()
		{
			nativeContext.OutputMerger.SetRenderTargets(MaxRTVCount, &_renderTargets, _depthStencilTarget);
		}

		public override void ClearRenderTarget(RenderTarget renderTarget, ColorRGBA color)
		{
			if(renderTarget == null)
			{
				nativeContext.ClearRenderTargetView(_swapChain.nativeBackBufferTarget, color);
			}
			else
			{
				Runtime.NotImplemented();
			}
		}

		public override void SetVertexBuffer(uint32 slot, Buffer buffer, uint32 stride, uint32 offset = 0)
		{
			// make stride and offset mutable so that we can take their pointers.
			var stride, offset;
			nativeContext.InputAssembler.SetVertexBuffers(slot, 1, &buffer.nativeBuffer, &stride, &offset);
		}

		public override void Draw(uint32 vertexCount, uint32 startVertexIndex = 0)
		{
			nativeContext.Draw(vertexCount, startVertexIndex);
		}

		public override void DrawIndexed(uint32 indexCount, uint32 startIndexLocation = 0, int32 vertexOffset = 0)
		{
			nativeContext.DrawIndexed(indexCount, startIndexLocation, vertexOffset);
		}

		public override void SetIndexBuffer(Buffer buffer, IndexFormat indexFormat = .Index16Bit, uint32 byteOffset = 0)
		{
			nativeContext.InputAssembler.SetIndexBuffer(buffer.nativeBuffer, indexFormat == .Index32Bit ? .R32_UInt : .R16_UInt, byteOffset);
		}

		protected override void SetRasterizerStateImpl()
		{
			nativeContext.Rasterizer.SetState(_currentRasterizerState.nativeRasterizerState);
		}

		public override void SetViewports(uint32 viewportsCount, GlitchyEngine.Renderer.Viewport* viewports)
		{
			nativeContext.Rasterizer.SetViewports(viewportsCount, (.)viewports);
		}

		public override void SetVertexLayout(VertexLayout vertexLayout)
		{
			nativeContext.InputAssembler.SetInputLayout(vertexLayout.nativeLayout);
		}

		public override void SetPrimitiveTopology(GlitchyEngine.Renderer.PrimitiveTopology primitiveTopology)
		{
			nativeContext.InputAssembler.SetPrimitiveTopology((DirectX.Common.PrimitiveTopology)primitiveTopology);
		}

		public override void SetVertexShader(VertexShader vertexShader)
		{
			//Todo: nativeContext.VertexShader.SetSamplers();
			vertexShader.Buffers.PlatformFetchNativeBuffers();
			nativeContext.VertexShader.SetConstantBuffers(0, vertexShader.Buffers.nativeBuffers.Count, &vertexShader.Buffers.nativeBuffers);
			//Todo: nativeContext.VertexShader.SetShaderResources();
			nativeContext.VertexShader.SetShader(vertexShader.nativeShader);
		}

		public override void SetPixelShader(PixelShader pixelShader)
		{
			//Todo: nativeContext.PixelShader.SetSamplers();
			pixelShader.Buffers.PlatformFetchNativeBuffers();
			nativeContext.PixelShader.SetConstantBuffers(0, pixelShader.Buffers.nativeBuffers.Count, &pixelShader.Buffers.nativeBuffers);
			//Todo: nativeContext.PixelShader.SetShaderResources();
			nativeContext.PixelShader.SetShader(pixelShader.nativeShader);
		}
	}
}
