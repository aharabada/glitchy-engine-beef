using GlitchyEngine.Math;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
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

		public override void Clear(RenderTarget renderTarget, ColorRGBA clearColor)
		{
			_context.ClearRenderTarget(renderTarget, clearColor);
		}

		public override void Clear(DepthStencilTarget target, float depthValue, uint8 stencilValue, DepthStencilClearFlag clearFlags)
		{
			_context.nativeContext.ClearDepthStencilView(target.nativeView, (.)clearFlags, depthValue, stencilValue);
		}

		public override void DrawIndexed(GeometryBinding geometry)
		{
			_context.DrawIndexed(geometry.IndexCount, geometry.IndexByteOffset, 0);
		}
	}
}
