using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer
{
	public class RenderTarget;

	//public abstract class GraphicsContext
	public class GraphicsContext
	{
		private RasterizerState _currentRasterizerState;

		//public abstract SwapChain SwapChain {get;}
		public extern SwapChain SwapChain {get;}
		
		/**
		 * The maximum number of simultaneous rendertargets supported. 
		 */
		//public static extern uint32 MaxRenderTargetCount();

		//public abstract void Init();
		public extern void Init();
		
		/**
		 * Sets a rendertarget.
		 * @param renderTarget The render target.
		 * @param slot The slot to which the rendertarget will be bound.
		 * @remarks When @RenderTarget is null the backbuffer will be bound.
		 * 			@BindRenderTargets has to be called in order to bind the rendertargets.
		 */
		//public abstract void SetRenderTarget(RenderTarget renderTarget, int slot = 0);
		public extern void SetRenderTarget(RenderTarget renderTarget, int slot = 0);

		/**
		 * Binds all.
		 * @param renderTarget The render target.
		 * @param slot The slot to which the rendertarget will be bound.
		 * @remarks When @RenderTarget is null the backbuffer will be bound.
		 */
		//public abstract void BindRenderTargets(); // Todo: maybe do this automatically when a drawcall is issued
		public extern void BindRenderTargets(); // Todo: maybe do this automatically when a drawcall is issued

		/**
		 * Sets all elements in the given render target to one value.
		 * @param renderTarget The render target.
		 * @param color The color to clear the render target with.
		 * @remarks When @renderTarget is null the backbuffer will be cleared.
		 */
		//public abstract void ClearRenderTarget(RenderTarget renderTarget, ColorRGBA color);
		public extern void ClearRenderTarget(RenderTarget renderTarget, ColorRGBA color);

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
		
		public void SetIndexBuffer(IndexBuffer indexBuffer, uint32 byteOffset = 0)
		{
			SetIndexBuffer(indexBuffer, indexBuffer.Format, byteOffset);
		}

		public extern void SetIndexBuffer(Buffer buffer, IndexFormat indexFormat = .Index16Bit, uint32 byteOffset = 0);

		public void SetRasterizerState(RasterizerState rasterizerState)
		{
			_currentRasterizerState = rasterizerState;
			SetRasterizerStateImpl();
		}

		protected extern void SetRasterizerStateImpl();

		public RasterizerState GetRasterizerState()
		{
			return _currentRasterizerState;
		}
	}
}