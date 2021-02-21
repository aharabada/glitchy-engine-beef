using System;
namespace GlitchyEngine.Renderer
{
	// TODO: add all features.
	public class DepthStencilTarget : RefCounted
	{
		protected internal GraphicsContext _context ~ _?.ReleaseRef();

		protected uint32 _width, _height;

		public uint32 Width => _width;
		public uint32 Height => _height;

		public this(GraphicsContext context, uint32 width, uint32 height)
		{
			_context = context..AddRef();
			_width = width;
			_height = height;

			PlatformCreate();
		}

		protected extern void PlatformCreate();

		public extern void Bind();

		public extern void Clear(float depthValue, uint8 stencilValue, DepthStencilClearFlag clearFlags);
	}
}
