using System;
using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer
{
	public static class RenderCommand
	{
		private static RendererAPI _rendererAPI;

		public static RendererAPI RendererAPI
		{
			get => _rendererAPI;
			set => _rendererAPI = value;
		}
		
		[Inline]
		public static void Clear(RenderTarget renderTarget, ColorRGBA color)
		{
			_rendererAPI.Clear(renderTarget, color);
		}

		[Inline]
		public static void DrawIndexed(GeometryBinding geometry)
		{
			_rendererAPI.DrawIndexed(geometry);
		}
	}
}
