using System;

namespace GlitchyEngine.Renderer
{
	public abstract class Texture : RefCounted
	{
		protected GraphicsContext _context ~ _?.ReleaseRef();

		protected SamplerState _samplerState ~ _?.ReleaseRef();
	
		public GraphicsContext Context => _context;

		public SamplerState SamplerState
		{
			get => _samplerState;
			set
			{
				if(_samplerState == value)
					return;

				_samplerState?.ReleaseRef();
				_samplerState = value;
				_samplerState?.AddRef();
			}
		}

		public abstract uint32 Width {get;}
		public abstract uint32 Height {get;}
		public abstract uint32 Depth {get;}
		public abstract uint32 ArraySize {get;}
		public abstract uint32 MipLevels {get;}

		public void Bind(uint32 slot = 0)
		{
			ImplBind(slot);

			if(_samplerState != null)
				_samplerState.Bind(slot);
		}

		protected extern void ImplBind(uint32 slot);

		protected this(GraphicsContext context)
		{
			_context = context..AddRef();
		}
	}

	public struct Texture2DDesc
	{
		public uint32 Width;
		public uint32 Height;
		public uint32 ArraySize;
		public uint32 MipLevels;
		public Format Format;
	}

	public class Texture2D : Texture
	{
		protected String _path ~ delete _;

		public override extern uint32 Width {get;}
		public override extern uint32 Height {get;}
		public override uint32 Depth => 1;
		public override extern uint32 ArraySize {get;}
		public override extern uint32 MipLevels {get;}
		
		protected this(GraphicsContext context) : base(context) {}

		public this(GraphicsContext context, String path) : base(context)
		{
			this._path = new String(path);
			LoadTexturePlatform();
		}

		protected extern void LoadTexturePlatform();
		
		protected extern void CreateTexturePlatform(Texture2DDesc desc, void* data, uint32 linePitch);
	}
}
