using System;

namespace GlitchyEngine.Renderer
{
	public class Effect : RefCounted
	{
		protected GraphicsContext _context; // Todo:???
		internal VertexShader _vs ~ _?.ReleaseRef();
		internal PixelShader _ps ~ _?.ReleaseRef();

		public GraphicsContext Context => _context;

		public VertexShader VertexShader
		{
			get => _vs;
			set
			{
				_vs?.ReleaseRef();
				_vs = value;
				_vs?.AddRef();
			}
		}
		
		public PixelShader PixelShader
		{
			get => _ps;
			set
			{
				_ps?.ReleaseRef();
				_ps = value;
				_ps?.AddRef();
			}
		}

		public void Bind(GraphicsContext context)
		{
			context.SetVertexShader(_vs);
			context.SetPixelShader(_ps);
		}

		[Obsolete("Will be removed in the future", false)]
		public this()
		{

		}

		public this(String vsPath, String vsEntry, String psPath, String psEntry)
		{
			Compile(vsPath, vsEntry, psPath, psEntry);
		}

		protected extern void Compile(String vsPath, String vsEntry, String psPath, String psEntry);
	}
}
