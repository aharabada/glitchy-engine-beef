namespace GlitchyEngine.Renderer
{
	public class SwapChain
	{
		private Viewport _backBufferViewport;

		public extern GraphicsContext Context {get;}

		/**
		 * Gets or Sets the backbuffers width.
		 * @remarks @ApplyChanges() needs to be called in order to apply the ganges.
		 */
		public extern uint32 Width {get; set;}
		/**
		 * Gets or Sets the backbuffers height.
		 * @remarks @ApplyChanges() needs to be called in order to apply the ganges.
		 */
		public extern uint32 Height {get; set;}

		public Viewport BackbufferViewport => _backBufferViewport;

		public extern void Init();

		/**
		 * Applies all changes to the swapchain.
		 */
		public extern void ApplyChanges();

		/**
		 * Swaps the front- and backbuffer.
		 */
		public extern void Present();
	}
}
