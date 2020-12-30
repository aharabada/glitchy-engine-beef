using System;
using System.IO;
using System.Collections;
using System.Diagnostics;

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

		protected BufferCollection _buffers ~ delete _;
		
		public GraphicsContext Context => _context;

		public BufferCollection Buffers => _buffers;

		public this(GraphicsContext context, String source, String entryPoint, ShaderDefine[] macros = null)
		{
			_buffers = new BufferCollection();
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
}
