using System;
using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer
{
	public enum DepthStencilClearFlag
	{
		None = 0,
		Depth = 1,
		Stencil = 2
	}

	public static class RenderCommand
	{
		private static RendererAPI _rendererAPI;

		public static RendererAPI RendererAPI
		{
			get => _rendererAPI;
			set => _rendererAPI = value;
		}

		[Inline]
		public static void Init()
		{
			_rendererAPI.Init();
		}

		[Inline]
		public static void Clear(RenderTarget2D renderTarget, ColorRGBA color)
		{
			_rendererAPI.Clear(renderTarget, color);
		}
		

		[Inline]
		public static void Clear(DepthStencilTarget target, float depthValue, uint8 stencilValue, DepthStencilClearFlag clearFlags)
		{
			_rendererAPI.Clear(target, depthValue, stencilValue, clearFlags);
		}

		[Inline]
		public static void DrawIndexed(GeometryBinding geometry)
		{
			_rendererAPI.DrawIndexed(geometry);
		}

		[Inline]
		public static void DrawIndexedInstanced(GeometryBinding geometry)
		{
			_rendererAPI.DrawIndexedInstanced(geometry);
		}
	}
}
