namespace GlitchyEngine.Renderer
{
	public class SwapChain
	{
		private GraphicsContext _context;

		private bool _changed;

		private uint32 _width, _height;

		private Viewport _backBufferViewport;

		private DepthStencilFormat _depthStencilFormat = .None;
		
		public RenderTarget2D _backBuffer ~ _?.ReleaseRef();

		public GraphicsContext Context => _context;

		/**
		 * Gets or Sets the backbuffers width.
		 * @remarks @ApplyChanges() needs to be called in order to apply the changes.
		 */
		public uint32 Width
		{
			get => _width;
			set
			{
				if(_width == value)
					return;

				_width = value;
				_changed = true;
			}
		}
		
		/**
		 * Gets or Sets the backbuffers height.
		 * @remarks @ApplyChanges() needs to be called in order to apply the changes.
		 */
		public uint32 Height
		{
			get => _height;
			set
			{
				if(_height == value)
					return;

				_height = value;
				_changed = true;
			}
		}

		public Viewport BackbufferViewport => _backBufferViewport;
		
		/**
		 * Gets or Sets the format of the depth stencil buffer.
		 * If set to DepthStencilFormat.None DepthStencilTarget will be null.
		 * @remarks @ApplyChanges() needs to be called in order to apply the changes.
		 */
		public DepthStencilFormat DepthStencilFormat
		{
			get => _depthStencilFormat;
			set
			{
				if(_depthStencilFormat == value)
					return;

				_depthStencilFormat = value;
				_changed = true;
			}
		}

		public RenderTarget2D BackBuffer => _backBuffer;

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
