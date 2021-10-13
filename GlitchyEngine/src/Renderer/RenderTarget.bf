using GlitchyEngine.Core;

namespace GlitchyEngine.Renderer
{
	public struct RenderTarget2DDescription
	{
		public uint32 Width;
		public uint32 Height;
		public uint32 ArraySize;
		public uint32 MipLevels;
		public Format PixelFormat;
		public CPUAccessFlags CpuAccess;
		public uint32 SampleCount;
		public uint32 SampleQuality;
		public DepthStencilFormat DepthStencilFormat;
		public bool IsSwapchainTarget;

		public this(Format pixelFormat, uint32 width, uint32 height, uint32 arraySize = 1, uint32 mipLevels = 1,
			DepthStencilFormat depthStencilFormat = .None, CPUAccessFlags cpuAccess = .None, uint32 sampleCount = 1, uint32 sampleQuality = 0, bool isSwapchainTarget = false)
		{
			PixelFormat = pixelFormat;
			Width = width;
			Height = height;
			ArraySize = arraySize;
			MipLevels = mipLevels;
			CpuAccess = cpuAccess;
			DepthStencilFormat = depthStencilFormat;

			SampleCount = sampleCount;
			SampleQuality = sampleQuality;

			IsSwapchainTarget = isSwapchainTarget;
		}
	}

	public class RenderTarget2D : RefCounter
	{
		internal GraphicsContext _context;

		private RenderTarget2DDescription _description;

		public RenderTarget2DDescription Description => _description;

		public uint32 Width => _description.Width;
		public uint32 Height => _description.Height;

		protected internal DepthStencilTarget _depthStenilTarget ~ _?.ReleaseRef();
		
		// TODO: DepthStencilTarget is just a renderTarget
		public DepthStencilTarget DepthStencilTarget => _depthStenilTarget;

		protected SamplerState _samplerState ~ _?.ReleaseRef();

		public SamplerState SamplerState
		{
			get => _samplerState;
			set
			{
				if(_samplerState == value)
					return;

				SetReference!(_samplerState, value);
			}
		}

		public this(GraphicsContext context, RenderTarget2DDescription description)
		{
			_context = context;
			_description = description;

			ApplyChanges();
		}

		/// Recreates the render target using the current description
		public void ApplyChanges()
		{
			PlatformApplyChanges();
		}

		public extern void Resize(uint32 width, uint32 height);

		protected extern void PlatformApplyChanges();
	}
}
