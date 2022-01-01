#if GE_GRAPHICS_DX11

using GlitchyEngine.Math;
using GlitchyEngine.Platform.DX11;

using internal GlitchyEngine.Renderer;
using internal GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.Renderer
{
	using internal GlitchyEngine.Renderer;

	extension RendererAPI
	{
		private GraphicsContext _context ~ _?.ReleaseRef();

		public GraphicsContext Context
		{
			get => _context;
			set => SetReference!(_context, value);
		}

		public static override API Api => .D3D11;

		public override void Init()
		{

		}

		private mixin RtOrBackbuffer(RenderTarget2D renderTarget)
		{
			renderTarget ?? _context.SwapChain.BackBuffer
		}

		public override void Clear(RenderTarget2D renderTarget, ColorRGBA color)
		{
			NativeContext.ClearRenderTargetView(RtOrBackbuffer!(renderTarget)._nativeRenderTargetView, color);
		}

		public override void Clear(DepthStencilTarget target, ClearOptions clearOptions, float depth, uint8 stencil)
		{
			if(target == null)
				return;

			DirectX.D3D11.ClearFlag flags = default;
			
			if(clearOptions.HasFlag(.Depth))
			{
				flags |= .Depth;
			}
			
			if(clearOptions.HasFlag(.Stencil))
			{
				flags |= .Stencil;
			}

			NativeContext.ClearDepthStencilView(target.nativeView, flags, depth, stencil);
		}

		public override void SetRenderTarget(RenderTarget2D renderTarget, int slot, bool setDepthBuffer)
		{
			_context.SetRenderTarget(renderTarget, slot, setDepthBuffer);
		}
		
		public override void SetDepthStencilTarget(DepthStencilTarget target)
		{
			_context.SetDepthStencilTarget(target);
		}

		public override void BindRenderTargets()
		{
			_context.BindRenderTargets();
		}

		private RasterizerState _currentRasterizerState ~ _?.ReleaseRef();

		public override void SetRasterizerState(RasterizerState rasterizerState)
		{
			SetReference!(_currentRasterizerState, rasterizerState);
			NativeContext.Rasterizer.SetState(_currentRasterizerState.nativeRasterizerState);
		}

		private BlendState _currentBlendState ~ _?.ReleaseRef();

		public override void SetBlendState(BlendState blendState, ColorRGBA blendFactor)
		{
			SetReference!(_currentBlendState, blendState);
			NativeContext.OutputMerger.SetBlendState(_currentBlendState.nativeBlendState, blendFactor);
		}
		
		private DepthStencilState _currentDepthStencilState ~ _?.ReleaseRef();

		public override void SetDepthStencilState(DepthStencilState depthStencilState, uint8 stencilReference)
		{
			SetReference!(_currentDepthStencilState, depthStencilState);
			NativeContext.OutputMerger.SetDepthStencilState(_currentDepthStencilState.nativeDepthStencilState, stencilReference);
		}

		public override void DrawIndexed(GeometryBinding geometry)
		{
			if(geometry.IsIndexed)
				_context.DrawIndexed(geometry.IndexCount, geometry.IndexByteOffset, 0);
			else
				_context.Draw(geometry.VertexCount, 0);
		}

		public override void DrawIndexedInstanced(GeometryBinding geometry)
		{
			NativeContext.DrawIndexedInstanced(geometry.IndexCount, geometry.InstanceCount, geometry.IndexByteOffset, 0, 0);
		}

		public override void SetViewport(Viewport viewport)
		{
			_context.SetViewport(viewport);
		}
	}
}

#endif
