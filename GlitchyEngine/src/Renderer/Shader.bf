using System;
using System.IO;
using System.Collections;

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

	public abstract class Shader : RefCounted
	{
		protected GraphicsContext _context ~ _?.ReleaseRef();

		protected BufferCollection _buffers ~ delete _;//:append _;
		
		public GraphicsContext Context => _context;

		public BufferCollection Buffers => _buffers;

		[AllowAppend]
		public this(GraphicsContext context, String source, String entryPoint, ShaderDefine[] macros = null)
		{
			// Todo: append as soon as it's fixed.
			//let buffers = new BufferCollection();
			_buffers = new BufferCollection();

			_context = context..AddRef();
			CompileFromSource(source, entryPoint);
		}

		public ~this()
		{

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