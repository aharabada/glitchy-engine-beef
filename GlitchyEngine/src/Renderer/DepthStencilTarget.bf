using System;
namespace GlitchyEngine.Renderer
{
	public enum DepthStencilFormat
	{
		D16_UNorm,
		D24_UNorm_S8_UInt,
		D32_Float,
		D32_Float_S8X24_UInt
	}

	// TODO: add all features.
	public class DepthStencilTarget : RefCounted
	{
		protected internal GraphicsContext _context ~ _?.ReleaseRef();

		protected uint32 _width, _height;
		protected DepthStencilFormat _format;

		public uint32 Width => _width;
		public uint32 Height => _height;
		public DepthStencilFormat Format => _format;

		public this(GraphicsContext context, uint32 width, uint32 height, DepthStencilFormat format = .D32_Float)
		{
			_context = context..AddRef();
			_width = width;
			_height = height;
			_format = format;

			PlatformCreate();
		}

		protected extern void PlatformCreate();

		public extern void Bind();

		public extern void Clear(float depthValue, uint8 stencilValue, DepthStencilClearFlag clearFlags);
	}
}