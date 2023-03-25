using System;
using GlitchyEngine.Content;

namespace GlitchyEngine.Renderer
{
	public class PixelShader : Shader
	{
		[AllowAppend]
		public this(StringView code, StringView? fileName, String entryPoint, IContentManager contentManager, ShaderDefine[] macros = null)
			 : base(code, fileName, entryPoint, contentManager, macros) { }
	}
}
