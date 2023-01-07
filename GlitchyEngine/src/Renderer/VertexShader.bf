using System;
using GlitchyEngine.Content;

namespace GlitchyEngine.Renderer
{
	public class VertexShader : Shader
	{
		[AllowAppend]
		public this(StringView code, StringView? fileName, String entryPoint, IContentManager contentManager = null, ShaderDefine[] macros = null)
			 : base(code, fileName, entryPoint, contentManager, macros) { }
	}
}
