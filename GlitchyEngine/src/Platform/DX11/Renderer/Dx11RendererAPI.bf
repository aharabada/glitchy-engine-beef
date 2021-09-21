using GlitchyEngine.Math;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
	using internal GlitchyEngine.Renderer;

	extension RendererAPI
	{
		private GraphicsContext _context;

		public GraphicsContext Context
		{
			get => _context;
			set => _context = value;
		}

		public static override API Api => .D3D11;

		public override void Init()
		{

		}

		public override void Clear(RenderTarget2D renderTarget, ColorRGBA clearColor)
		{
			_context.ClearRenderTarget(renderTarget, clearColor);
		}

		public override void Clear(DepthStencilTarget target, float depthValue, uint8 stencilValue, DepthStencilClearFlag clearFlags)
		{
			_context.nativeContext.ClearDepthStencilView(target.nativeView, (.)clearFlags, depthValue, stencilValue);
		}

		public override void Clear(RenderTarget2D renderTarget, float depthValue, uint8 stencilValue, DepthStencilClearFlag clearFlags)
		{
			_context.nativeContext.ClearDepthStencilView(renderTarget._depthStenilTarget.nativeView, (.)clearFlags, depthValue, stencilValue);
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
			_context.nativeContext.DrawIndexedInstanced(geometry.IndexCount, geometry.InstanceCount, geometry.IndexByteOffset, 0, 0);
		}

		public override void SetViewport(Viewport viewport)
		{
			_context.SetViewport(viewport);
		}
	}
}
