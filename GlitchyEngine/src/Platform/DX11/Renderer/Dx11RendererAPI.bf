using GlitchyEngine.Math;

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

		public override void Clear(RenderTarget renderTarget, ColorRGBA clearColor)
		{
			_context.ClearRenderTarget(renderTarget, clearColor);
		}

		public override void DrawIndexed(GeometryBinding geometry)
		{
			_context.DrawIndexed(geometry.IndexCount, geometry.IndexByteOffset, 0);
		}
	}
}
