#if GE_GRAPHICS_DX11

using DirectX.D3D11;
using DirectX.DXGI.DXGI1_2;
using System.Diagnostics;
using GlitchyEngine.Platform.DX11;

using internal GlitchyEngine.Renderer;
using internal GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.Renderer
{
	public extension SwapChain
	{
		internal DirectX.DXGI.IDXGIDevice* nativeDxgiDevice;
		internal IDXGISwapChain1* nativeSwapChain;

		public this(GraphicsContext context)
		{
			Debug.Profiler.ProfileFunction!();

			_context = context;

			SetResolutionFromWindow();
		}

		public ~this()
		{
			Debug.Profiler.ProfileFunction!();

			nativeDxgiDevice?.Release();
			nativeSwapChain?.Release();
		}

		void SetResolutionFromWindow()
		{
			DirectX.Windows.Winuser.GetClientRect(_context.nativeWindowHandle, let rect);

			Width = (.)(rect.Right - rect.Left);
			Height = (.)(rect.Bottom - rect.Top);
		}

		public override void Init()
		{
			Debug.Profiler.ProfileFunction!();

			ApplyChanges();
		}

		public override void ApplyChanges()
		{
			Debug.Profiler.ProfileFunction!();

			if(!_changed)
				return;

			UpdateSwapchain();
		}

		/**
		 * Initializes the swapchain.
		 */
		public void UpdateSwapchain()
		{
			Debug.Profiler.ProfileFunction!();

			Log.EngineLogger.Trace($"Updating swap chain ({_width}, {_height})");

			uint32 backBufferCount = 2;
			Format backBufferFormat = .R8G8B8A8_UNorm;
			Format backBufferViewFormat = .R8G8B8A8_UNorm; // _SRGB

			if(nativeSwapChain != null)
			{
				//nativeBackBufferTarget.Release();
				_backBuffer.ReleaseRef();

				var resizeResult = nativeSwapChain.ResizeBuffers(backBufferCount, _width, _height, backBufferFormat, .None);
				if(resizeResult.Failed)
				{
					Log.EngineLogger.Error($"Failed to resize swap chain. Message({(int)resizeResult}):{resizeResult}");
				}
			}
			else
			{
				NativeDevice.QueryInterface(out nativeDxgiDevice);

				nativeDxgiDevice.GetAdapter(let adapter);
				adapter.GetParent<DirectX.DXGI.IDXGIFactory2>(let factory);
				adapter.Release();

				SwapChainDescription1 swDesc = .();
				swDesc.Width = _width;
				swDesc.Height = _height;
				swDesc.Format = backBufferFormat;
				swDesc.SampleDescription = .(1, 0);
				swDesc.BufferUsage = .RenderTargetOutput | .ShaderInput;
				swDesc.BufferCount = backBufferCount;
				swDesc.SwapEffect = .FlipDiscard;

				SwapChainFullscreenDescription fsSwapChainDesc = .();
				fsSwapChainDesc.Windowed = true;

				var createResult = factory.CreateSwapChainForHwnd((.)NativeDevice, _context.nativeWindowHandle, ref swDesc, &fsSwapChainDesc, null, &nativeSwapChain);
				if(createResult.Failed)
				{
					Log.EngineLogger.Error($"Failed to create swap chain. Message({(int)createResult}):{createResult}");
				}

				factory.Release();
			}

			RenderTarget2DDescription desc = .(backBufferFormat, _width, _height);
			desc.DepthStencilFormat = _depthStencilFormat;
			desc.IsSwapchainTarget = true;

			// Todo: perhaps just update the render target
			_backBuffer = new RenderTarget2D(desc);
			
			_backBufferViewport = GlitchyEngine.Renderer.Viewport(0, 0, _width, _height, 0.0f, 1.0f);
		}

		internal void GetBackbuffer(out ID3D11Texture2D* texture)
		{
			Debug.Profiler.ProfileResourceFunction!();

			var result = nativeSwapChain.GetBuffer<ID3D11Texture2D>(0, out texture);
			Log.EngineLogger.Assert(result.Succeeded, "Failed to get backbuffer.");
		}

		public override void Present()
		{
			Debug.Profiler.ProfileFunction!();

			nativeSwapChain.Present(Application.Get().Window.IsVSync ? 1 : 0, .None);
		}
	}
}

#endif
