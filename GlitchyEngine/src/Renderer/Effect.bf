using System;

namespace GlitchyEngine.Renderer
{
	public class Effect
	{
		protected GraphicsContext _context;
		internal VertexShader _vs;
		internal PixelShader _ps;

		public GraphicsContext Context => _context;

		public VertexShader VertexShader
		{
			get => _vs;
			set => _vs = value;
		}
		
		public PixelShader PixelShader
		{
			get => _ps;
			set => _ps = value;
		}

		public void Bind(GraphicsContext context)
		{
			context.SetVertexShader(_vs);
			context.SetPixelShader(_ps);
		}
	}
}
