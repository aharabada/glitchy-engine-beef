using System;

namespace GlitchyEngine.Renderer
{
	public class PixelShader : Shader
	{
		[AllowAppend]
		public this(String source, String entryPoint, ShaderDefine[] macros = null)
			 : base(source, entryPoint, macros) { }

		public override extern void CompileFromSource(String code, String entryPoint, ShaderDefine[] macros = null);
	}
}
