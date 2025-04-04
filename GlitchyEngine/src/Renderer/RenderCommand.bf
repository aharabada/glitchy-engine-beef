using System;
using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer
{
	public enum ClearOptions
	{
		None = 0,
		Color = 1,
		Depth = 2,
		Stencil = 4,

		ColorDepth = Color | Depth,
		ColorStencil = Color | Stencil,
		DepthStencil = Depth | Stencil,
		All = Color | Depth | Stencil
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
			Debug.Profiler.ProfileFunction!();

			_rendererAPI.Init();
		}

		// REPORT!!!!!!!!!
		// Inline doesn't compile
		//[Inline]
		public static void Clear(RenderTarget2D renderTarget, ColorRGBA color)
		{
			_rendererAPI.Clear(renderTarget, color);
		}

		public static void Clear(DepthStencilTarget target, ClearOptions options, float depth, uint8 stencil)
		{
			_rendererAPI.Clear(target, options, depth, stencil);
		}

		public static void Clear(RenderTarget2D renderTarget, ClearOptions options, ColorRGBA color, float depth, uint8 stencil)
		{
			_rendererAPI.Clear(renderTarget, options, color, depth, stencil);
		}

		public static void Clear(RenderTargetGroup renderTarget, ClearOptions options, ColorRGBA? color = null, float? depth = null, uint8? stencil = null)
		{
			_rendererAPI.Clear(renderTarget, options, color, depth, stencil);
		}

		public static void SetRenderTarget(RenderTarget2D renderTarget, int slot = 0, bool setDepthBuffer = false)
		{
			_rendererAPI.SetRenderTarget(renderTarget, slot, setDepthBuffer);
		}

		public static void SetRenderTargetGroup(RenderTargetGroup renderTarget, bool setDepthBuffer = true)
		{
			_rendererAPI.SetRenderTargetGroup(renderTarget, setDepthBuffer);
		}

		public static void SetDepthStencilTarget(DepthStencilTarget target)
		{
			_rendererAPI.SetDepthStencilTarget(target);
		}

		public static void UnbindRenderTargets()
		{
			_rendererAPI.UnbindRenderTargets();
		}

		public static void BindRenderTargets()
		{
			_rendererAPI.BindRenderTargets();
		}

		public static void SetRasterizerState(RasterizerState rasterizerState)
		{
			_rendererAPI.SetRasterizerState(rasterizerState);
		}

		public static void SetBlendState(BlendState blendState, ColorRGBA blendFactor = .White)
		{
			_rendererAPI.SetBlendState(blendState, blendFactor);
		}
		
		public static void SetDepthStencilState(DepthStencilState depthStencilState, uint8 stencilReference = 0)
		{
			_rendererAPI.SetDepthStencilState(depthStencilState, stencilReference);
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

		public static void SetViewport(Viewport viewport)
		{
			_rendererAPI.SetViewport(viewport);
		}

		public static void SetViewport(float left, float top, float width, float height, float minDepth = 0.0f, float maxDepth = 1.0f)
		{
			SetViewport(.(left, top, width, height, minDepth, maxDepth));
		}

		public static void UnbindTextures()
		{
			_rendererAPI.UnbindTextures();
		}

		public static void BindConstantBuffer(Buffer buffer, int slot, ShaderStage stage)
		{
			_rendererAPI.BindConstantBuffer(buffer, slot, stage);
		}

		public static void BindConstantBuffers(BufferCollection constantBuffers, ShaderStage stage = .All)
		{
			_rendererAPI.BindConstantBuffers(constantBuffers, stage);
		}

		public static void BindVertexShader(VertexShader vertexShader)
		{
			_rendererAPI.BindVertexShader(vertexShader);
		}

		public static void BindPixelShader(PixelShader pixelShader)
		{
			_rendererAPI.BindPixelShader(pixelShader);
		}

		public static void BindTexture(TextureViewBinding textureBinding, int slot, ShaderStage shaderStage)
		{
			_rendererAPI.BindTexture(textureBinding, slot, shaderStage);
		}
	}
}
