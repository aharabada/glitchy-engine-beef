using System;
using System.Diagnostics;
using DirectX.Common;
using DirectX.D3D11;
using DirectX.D3D11.SDKLayers;
using DirectX.DXGI.DXGI1_2;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;

using GlitchyEngine.Platform.DX11;

using internal GlitchyEngine.Renderer;
//using internal GlitchyEngine.Platform.DX11.Renderer;

namespace GlitchyEngine.Renderer
//namespace GlitchyEngine.Platform.DX11.Renderer
{
	/// DirectX 11 specific implementation of the GraphicsContext
	extension GraphicsContext
	//public class Dx11Context : GraphicsContext
	{
		//private Dx11SwapChain _swapChain;
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
			//_swapChain = new Dx11SwapChain(this);
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

			var deviceResult = D3D11.CreateDevice(null, .Hardware, 0, deviceFlags, levels, &nativeDevice, let deviceLevel, &nativeContext);
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
			
			Dx11Cheater.Device = nativeDevice;
			Dx11Cheater.ImmediateContext = nativeContext;

			Log.EngineLogger.Trace("D3D11 Device and Context created (Feature level: {})", deviceLevel);
		}

		

		private ID3D11RenderTargetView*[MaxRTVCount] _renderTargets;

		public override void SetRenderTarget(RenderTarget renderTarget, int slot = 0)
		{
			if(renderTarget == null)
			{
				_renderTargets[slot] = _swapChain.nativeBackBufferTarget;
				//_immediateContext.OutputMerger.SetRenderTargets(1, &_swapChain._backBufferTarget, null);
			}
			else
			{
				Runtime.NotImplemented();
			}
		}

		public override void BindRenderTargets()
		{
			nativeContext.OutputMerger.SetRenderTargets(MaxRTVCount, &_renderTargets, null);
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
	}
}
