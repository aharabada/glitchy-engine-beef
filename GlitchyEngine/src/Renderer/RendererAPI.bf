using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer
{
	public class RendererAPI
	{
		public enum API
		{
			None,
			D3D11
		}

		/**
		 * Gets which graphics API is active.
		 */
		public static extern API Api { get; }

		public extern void Init();

		public extern void Clear(RenderTarget2D renderTarget, ColorRGBA clearColor);

		public extern void Clear(DepthStencilTarget target, float depthValue, uint8 stencilValue, DepthStencilClearFlag clearFlags);

		public extern void DrawIndexed(GeometryBinding geometry);

		public extern void DrawInstanced(GeometryBinding geometry);

		public extern void DrawIndexedInstanced(GeometryBinding geometry);

		public extern void SetViewport(Viewport viewport);
	}
}
