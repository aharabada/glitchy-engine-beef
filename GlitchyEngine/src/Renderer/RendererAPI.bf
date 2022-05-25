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

		public extern void Clear(RenderTarget2D renderTarget, ColorRGBA color);

		public extern void Clear(DepthStencilTarget target, ClearOptions options, float depth, uint8 stencil);
		
		//public extern void Clear(RenderTargetGroup renderTarget, ClearOptions options, ColorRGBA? color = null, float? depth = null, uint8? stencil = null);
		public extern void Clear(RenderTargetGroup renderTarget, ClearOptions options, ClearColor? color = null, float? depth = null, uint8? stencil = null);

		public void Clear(RenderTarget2D renderTarget, ClearOptions options, ColorRGBA color, float depth, uint8 stencil)
		{
			Debug.Profiler.ProfileRendererFunction!();

			var actualRt = (renderTarget ?? GraphicsContext.Get().SwapChain.BackBuffer);

			if(options.HasFlag(.Color))
				Clear(actualRt, color);

			if((options.HasFlag(.Depth) || options.HasFlag(.Stencil)) && actualRt.DepthStencilTarget != null)
				Clear(actualRt.DepthStencilTarget, options, depth, stencil);
		}

		public extern void SetRenderTarget(RenderTarget2D renderTarget, int slot, bool setDepthBuffer);

		public extern void SetRenderTargetGroup(RenderTargetGroup renderTarget, bool setDepthBuffer);

		public extern void SetDepthStencilTarget(DepthStencilTarget target);

		public extern void UnbindRenderTargets();

		public extern void BindRenderTargets();

		public extern void SetRasterizerState(RasterizerState rasterizerState);

		public extern void SetBlendState(BlendState blendState, ColorRGBA blendFactor);

		public extern void SetDepthStencilState(DepthStencilState depthStencilState, uint8 stencilReference);

		public extern void DrawIndexed(GeometryBinding geometry);

		public extern void DrawInstanced(GeometryBinding geometry);

		public extern void DrawIndexedInstanced(GeometryBinding geometry);

		public extern void SetViewport(Viewport viewport);

		public extern void UnbindTextures();
	}
}
