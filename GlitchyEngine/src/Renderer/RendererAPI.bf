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

		public extern void Clear(RenderTarget renderTarget, ColorRGBA clearColor);

		public extern void DrawIndexed(GeometryBinding geometry);
	}
}
