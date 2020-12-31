using System;

namespace GlitchyEngine.Renderer
{
	public class VertexShader : Shader
	{
		[AllowAppend]
		public this(GraphicsContext context, String source, String entryPoint, ShaderDefine[] macros = null)
			 : base(context, source, entryPoint, macros) { }

		public override extern void CompileFromSource(String code, String entryPoint, ShaderDefine[] macros = null);
	}
}
