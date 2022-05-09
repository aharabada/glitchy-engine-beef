using System;

namespace GlitchyEngine.Renderer
{
	public class PixelShader : Shader
	{
		[AllowAppend]
		public this(StringView code, StringView? fileName, String entryPoint, ShaderDefine[] macros = null)
			 : base(code, fileName, entryPoint, macros) { }
	}
}
