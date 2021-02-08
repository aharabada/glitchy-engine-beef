using System;

namespace GlitchyEngine.Renderer
{
	public abstract class Texture : RefCounted
	{
		protected GraphicsContext _context ~ _?.ReleaseRef();
		
		public GraphicsContext Context => _context;

		public abstract uint32 Width {get;}
		public abstract uint32 Height {get;}
		public abstract uint32 Depth {get;}
		public abstract uint32 ArraySize {get;}
		public abstract uint32 MipLevels {get;}

		public abstract void Bind(uint32 slot = 0);

		protected this(GraphicsContext context)
		{
			_context = context..AddRef();
		}
	}

	public class Texture2D : Texture
	{
		protected String _path ~ delete _;

		public override extern uint32 Width {get;}
		public override extern uint32 Height {get;}
		public override uint32 Depth => 1;
		public override extern uint32 ArraySize {get;}
		public override extern uint32 MipLevels {get;}

		public override extern void Bind(uint32 slot = 0);
		
		public this(GraphicsContext context, String path) : base(context)
		{
			this._path = new String(path);
			LoadTexturePlatform();
		}

		protected extern void LoadTexturePlatform();
	}
}
