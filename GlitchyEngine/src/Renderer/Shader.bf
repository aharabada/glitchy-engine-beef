using System;
using System.IO;

namespace GlitchyEngine.Renderer
{
	public struct ShaderDefine
	{
		public String Name;
		public String Definition;

		public this() => this = default;

		public this(String name, String definition)
		{
			Name = name;
			Definition = definition;
		}
	}

	public abstract class Shader
	{
		protected GraphicsContext _context;

		public GraphicsContext Context => _context;

		public this(GraphicsContext context, String source, String entryPoint, ShaderDefine[] macros = null)
		{
			_context = context;
			CompileFromSource(source, entryPoint);
		}

		public static mixin FromFile<T>(GraphicsContext context, String fileName, String entryPoint, ShaderDefine[] macros = null) where T : Shader
		{
			String fileContent = new String();

			File.ReadAllText(fileName, fileContent, true);
			T shader = new T(context, fileContent, entryPoint, macros);

			delete fileContent;

			shader
		}

		public abstract void CompileFromSource(String code, String entryPoint, ShaderDefine[] macros = null);
	}

	public class PixelShader : Shader
	{
		public this(GraphicsContext context, String source, String entryPoint, ShaderDefine[] macros = null)
			 : base(context, source, entryPoint, macros) { }

		public override extern void CompileFromSource(String code, String entryPoint, ShaderDefine[] macros = null);
	}
}
