using System;
using DirectX;
using DirectX.D3D11;
using DirectX.Common;
using System.Diagnostics;
using DirectX.DXGI;
using DirectX.DXGI.DXGI1_2;
using static System.Windows;

namespace GlitchyEngine.Platform.DX11
{
	public static class DirectX
	{
		public static ID3D11Device* Device;
		public static ID3D11DeviceContext* ImmediateContext;
		
		public static IDXGIDevice* DxgiDevice;
		public static IDXGISwapChain1* SwapChain;

		public static ID3D11RenderTargetView* BackBufferTarget;
		public static Viewport BackBufferViewport;

		static HWnd _windowHandle;

		static ~this()
		{
			Shutdown();
		}

		public static void Init(HWnd windowHandle, uint32 width, uint32 height)
		{
			_windowHandle = windowHandle;

			InitDevice();
			UpdateSwapchain(width, height);
		}

		/**
		 * Initializes the Device and ImmediateContext.
		 */
		static void InitDevice()
		{
			IUnknown.ReleaseAndNull!(ref Device);
			IUnknown.ReleaseAndNull!(ref ImmediateContext);
			
			Log.EngineLogger.Trace("Creating D3D11 Device and Context...");

			DeviceCreationFlags deviceFlags = .None;
#if DEBUG
			deviceFlags |= .Debug;
#endif

			FeatureLevel[] levels = scope .(.Level_11_0);

			FeatureLevel deviceLevel = ?;
			var deviceResult = D3D11.CreateDevice(null, .Hardware, 0, deviceFlags, levels, &Device, &deviceLevel, &ImmediateContext);
			Debug.Assert(deviceResult.Succeeded, scope $"Failed to create D3D11 Device. Message(0x{(int32)deviceResult}): {deviceResult}");

			Log.EngineLogger.Trace("D3D11 Device and Context created (Feature level: {})", deviceLevel);
		}

		static uint32 _width, _height;

		/**
		 * Initializes the swapchain.
		 */
		public static void UpdateSwapchain(uint32 width, uint32 height)
		{
			if(_width == width && _height == height)
				return;

			_width = width;
			_height = height;

			Log.EngineLogger.Trace("Updating swap chain ({}, {})", width, height);

			uint32 backBufferCount = 2;
			Format backBufferFormat = .R8G8B8A8_UNorm;
			Format backBufferViewFormat = .R8G8B8A8_UNorm; // _SRGB

			if(SwapChain != null)
			{
				BackBufferTarget.Release();

				var resizeResult = SwapChain.ResizeBuffers(backBufferCount, width, height, backBufferFormat, .None);
				Debug.Assert(resizeResult.Succeeded, scope $"Failed to resize swap chain. Message({(int32)resizeResult}):{resizeResult}");
			}
			else
			{
				Device.QueryInterface(out DxgiDevice);

				DxgiDevice.GetAdapter(let adapter);
				adapter.GetParent<IDXGIFactory2>(let factory);
				adapter.Release();

				SwapChainDescription1 swDesc = .();
				swDesc.Width = width;
				swDesc.Height = height;
				swDesc.Format = backBufferFormat;
				swDesc.SampleDescription = .(1, 0);
				swDesc.BufferUsage = .RenderTargetOutput;
				swDesc.BufferCount = backBufferCount;
				swDesc.SwapEffect = .FlipDiscard;

				SwapChainFullscreenDescription fsSwapChainDesc = .();
				fsSwapChainDesc.Windowed = true;

				var createResult = factory.CreateSwapChainForHwnd((.)Device, _windowHandle, ref swDesc, &fsSwapChainDesc, null, &SwapChain);
				Debug.Assert(createResult.Succeeded, scope $"Failed to create swap chain. Message({(int32)createResult}):{createResult}");

				factory.Release();
			}

			SwapChain.GetBuffer<ID3D11Texture2D>(0, let backBuffer);

			RenderTargetViewDescription rtvDesc = .(backBuffer, .Texture2D, backBufferViewFormat);
			Device.CreateRenderTargetView(backBuffer, &rtvDesc, &BackBufferTarget);

			BackBufferViewport = Viewport(0, 0, width, height, 0.0f, 1.0f);

			backBuffer.Release();
		}

		public static void Shutdown()
		{
			IUnknown.ReleaseAndNull!(ref Device);
			IUnknown.ReleaseAndNull!(ref ImmediateContext);

			IUnknown.ReleaseAndNull!(ref DxgiDevice);
			IUnknown.ReleaseAndNull!(ref SwapChain);

			IUnknown.ReleaseAndNull!(ref BackBufferTarget);
		}

		public static void Present()
		{
			SwapChain.Present(Application.Get().Window.IsVSync ? 1 : 0, .None);
		}
	}
}
