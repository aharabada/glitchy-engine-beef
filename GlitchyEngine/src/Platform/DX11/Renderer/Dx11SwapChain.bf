using DirectX.D3D11;
using DirectX.DXGI.DXGI1_2;
using GlitchyEngine.Platform.DX11;
using System.Diagnostics;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
	public extension SwapChain
	{
		private GraphicsContext _context;

		private bool _changed;

		private uint32 _width, _height;
		
		internal DirectX.DXGI.IDXGIDevice* nativeDxgiDevice;
		internal IDXGISwapChain1* nativeSwapChain;

		internal ID3D11RenderTargetView* nativeBackBufferTarget;
		private DirectX.D3D11.Viewport _backBufferViewport;

		public override uint32 Width
		{
			get => _width;

			set
			{
				if(_width == value)
					return;

				_width = value;
				_changed = true;
			}
		}
		
		public override uint32 Height
		{
			get => _height;

			set
			{
				if(_height == value)
					return;

				_height = value;
				_changed = true;
			}
		}

		public override GraphicsContext Context => _context;

		//public this(Dx11Context context)
		public this(GraphicsContext context)
		{
			_context = context;

			SetResolutionFromWindow();
		}

		public ~this()
		{
			nativeDxgiDevice?.Release();
			nativeSwapChain?.Release();
			nativeBackBufferTarget?.Release();
		}

		void SetResolutionFromWindow()
		{
			DirectX.Windows.Winuser.GetClientRect(_context.nativeWindowHandle, let rect);

			Width = (.)(rect.Right - rect.Left);
			Height = (.)(rect.Bottom - rect.Top);
		}

		public override void Init()
		{
			ApplyChanges();
		}

		public override void ApplyChanges()
		{
			if(!_changed)
				return;

			UpdateSwapchain();
		}

		/**
		 * Initializes the swapchain.
		 */
		public void UpdateSwapchain()
		{
			Log.EngineLogger.Trace("Updating swap chain ({}, {})", _width, _height);

			uint32 backBufferCount = 2;
			Format backBufferFormat = .R8G8B8A8_UNorm;
			Format backBufferViewFormat = .R8G8B8A8_UNorm; // _SRGB

			if(nativeSwapChain != null)
			{
				nativeBackBufferTarget.Release();

				var resizeResult = nativeSwapChain.ResizeBuffers(backBufferCount, _width, _height, backBufferFormat, .None);
				Debug.Assert(resizeResult.Succeeded, scope $"Failed to resize swap chain. Message({(int32)resizeResult}):{resizeResult}");
			}
			else
			{
				_context.nativeDevice.QueryInterface(out nativeDxgiDevice);

				nativeDxgiDevice.GetAdapter(let adapter);
				adapter.GetParent<DirectX.DXGI.IDXGIFactory2>(let factory);
				adapter.Release();

				SwapChainDescription1 swDesc = .();
				swDesc.Width = _width;
				swDesc.Height = _height;
				swDesc.Format = backBufferFormat;
				swDesc.SampleDescription = .(1, 0);
				swDesc.BufferUsage = .RenderTargetOutput;
				swDesc.BufferCount = backBufferCount;
				swDesc.SwapEffect = .FlipDiscard;

				SwapChainFullscreenDescription fsSwapChainDesc = .();
				fsSwapChainDesc.Windowed = true;

				var createResult = factory.CreateSwapChainForHwnd((.)_context.nativeDevice, _context.nativeWindowHandle, ref swDesc, &fsSwapChainDesc, null, &nativeSwapChain);
				Debug.Assert(createResult.Succeeded, scope $"Failed to create swap chain. Message({(int32)createResult}):{createResult}");

				factory.Release();
				
				Dx11Cheater.SwapChain = nativeSwapChain;
			}

			nativeSwapChain.GetBuffer<ID3D11Texture2D>(0, let backBuffer);

			RenderTargetViewDescription rtvDesc = .(backBuffer, .Texture2D, backBufferViewFormat);
			_context.nativeDevice.CreateRenderTargetView(backBuffer, &rtvDesc, &nativeBackBufferTarget);

			Dx11Cheater.BackbufferTarget = nativeBackBufferTarget;

			_backBufferViewport = DirectX.D3D11.Viewport(0, 0, _width, _height, 0.0f, 1.0f);
			
			Dx11Cheater.BackbufferViewport = _backBufferViewport;

			backBuffer.Release();
		}

		public override void Present()
		{
			nativeSwapChain.Present(Application.Get().Window.IsVSync ? 1 : 0, .None);
		}
	}
}
