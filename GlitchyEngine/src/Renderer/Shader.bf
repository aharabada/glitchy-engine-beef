using System;
using System.IO;
using System.Collections;
using GlitchyEngine.Core;

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

	public abstract class Shader : RefCounter
	{
		protected internal BufferCollection _buffers ~ _.ReleaseRef();//:append _;

		protected ShaderTextureCollection _textures ~ delete _;
		
		public BufferCollection Buffers => _buffers;

		public ShaderTextureCollection Textures => _textures;

		[AllowAppend]
		public this(StringView code, StringView? fileName, String entryPoint, ShaderDefine[] macros = null)
		{
			Debug.Profiler.ProfileResourceFunction!();

			// Todo: append as soon as it's fixed.
			//let buffers = new BufferCollection();
			_buffers = new BufferCollection();
			_textures = new ShaderTextureCollection();

			CompileFromSource(code, fileName, entryPoint);
		}

		public ~this()
		{
			Debug.Profiler.ProfileResourceFunction!();
		}

		public static mixin FromFile<T>(String fileName, String entryPoint, ShaderDefine[] macros = null) where T : Shader
		{
			Debug.Profiler.ProfileResourceFunction!();

			String fileContent = new String();
			File.ReadAllText(fileName, fileContent, true);
			T shader = new T(fileContent, (StringView)fileName, entryPoint, macros);

			delete fileContent;

			shader
		}

		public abstract void CompileFromSource(StringView code, StringView? fileName, String entryPoint, ShaderDefine[] macros = null);
	}
}
