namespace GlitchyEngine.Renderer
{
	public class SwapChain
	{
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
