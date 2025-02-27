using System;
using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer
{
	public class GraphicsContext : RefCounter
	{
		private static GraphicsContext s_GraphicsContext;
		public static GraphicsContext Get() => s_GraphicsContext;

		public extern SwapChain SwapChain {get;}

		protected extern void PlatformConstruct();

		/**
		 * The maximum number of simultaneous rendertargets supported. 
		 */
		//public static extern uint32 MaxRenderTargetCount();

		public extern void Init();
		
		/** @brief Sets a depthtarget.
		 * @BindRenderTargets has to be called in order to bind the rendertargets.
		 * @param renderTarget The render target to set. If null, the backbuffer will be set.
		 * @param slot The slot to which the rendertarget will be bound. If 0 the depth buffer of the current render target will be set. If it has no depthbuffer the current will be unset.
		 */
		public extern void SetDepthStencilTarget(DepthStencilTarget target);

		/** @brief Sets a rendertarget to the given slot.
		 * @BindRenderTargets has to be called in order to bind the rendertargets.
		 * @param renderTarget The render target to set. If null, the backbuffer will be set.
		 * @param slot The slot to which the rendertarget will be bound. If 0 the depth buffer of the current render target will be set. If it has no depthbuffer the current will be unset.
		 * @param setDepthTarget If set to true the depth stencil target of the given renderTarget will be bound (only applies if slot is 0).
		 */
		public extern void SetRenderTarget(RenderTarget2D renderTarget, int slot = 0, bool setDepthTarget = true);
		
		/**
		 * Unbinds all rendertargets.
		 */
		public extern void UnbindRenderTargets();

		/**
		 * Binds all.
		 * @param renderTarget The render target.
		 * @param slot The slot to which the rendertarget will be bound.
		 * @remarks When @RenderTarget is null the backbuffer will be bound.
		 */
		public extern void BindRenderTargets(); // Todo: maybe do this automatically when a drawcall is issued

		/**
		 * Sets all elements in the given render target to one value.
		 * @param renderTarget The render target.
		 * @param color The color to clear the render target with.
		 * @remarks When @renderTarget is null the backbuffer will be cleared.
		 */
		public extern void ClearRenderTarget(RenderTarget2D renderTarget, ColorRGBA color);

		//public abstract void SetViewport(Viewport viewport);

		/**
		 * Binds a VertexBuffer to the pipeline.
		 * @param buffer The vertex buffer to bind.
		 * 			Note: the buffer has to have BindFlags.Vertex!
		 * @param slot The slot the vertex buffer will be bound to.
		 * @param offset The offset in bytes from the start of the buffer.
		 * @param stride The stride of the 
		 */
		public extern void SetVertexBuffer(uint32 slot, Buffer buffer, uint32 stride, uint32 offset = 0);

		/**
		 * Binds a VertexBuffer to the pipeline.
		 */
		public void SetVertexBuffer(uint32 slot, VertexBufferBinding binding)
		{
			SetVertexBuffer(slot, binding.Buffer, binding.Stride, binding.Offset);
		}

		public extern void Draw(uint32 vertexCount, uint32 startVertexIndex = 0);

		public extern void DrawIndexed(uint32 indexCount, uint32 startIndexLocation = 0, int32 vertexOffset = 0);

		public extern void DrawIndexedInstanced(uint32 indexCountPerInstance, uint32 instanceCount, uint32 startIndexLocation, int32 baseVertexLocation, uint32 startInstanceLocation);
		
		public void SetIndexBuffer(IndexBuffer indexBuffer, uint32 byteOffset = 0)
		{
			SetIndexBuffer(indexBuffer, indexBuffer.Format, byteOffset);
		}

		public extern void SetIndexBuffer(Buffer buffer, IndexFormat indexFormat = .Index16Bit, uint32 byteOffset = 0);

		protected extern void SetRasterizerStateImpl();

		internal void SetViewport(Viewport viewport)
		{
			var viewport;
			SetViewports(1, &viewport);
		}
		
		[Inline]
		public void SetViewports(Span<Viewport> viewports)
		{
			SetViewports((.)viewports.Length, viewports.Ptr);
		}

		public extern void SetViewports(uint32 viewportsLength, Viewport* viewports);

		public extern void SetVertexLayout(VertexLayout vertexLayout);

		public extern void SetPrimitiveTopology(PrimitiveTopology primitiveTopology);
		
		public extern void BindVertexShader(VertexShader vertexShader);

		public extern void BindPixelShader(PixelShader pixelShader);

		public extern void UnbindTextures();

		public extern void BindConstantBuffer(Buffer buffer, int slot, ShaderStage stage);

		public extern void BindConstantBuffers(BufferCollection bufferCollection, ShaderStage shaderStage);

		public extern void BindTexture(TextureViewBinding textureBinding, int slot, ShaderStage shaderStage);
	}
}
