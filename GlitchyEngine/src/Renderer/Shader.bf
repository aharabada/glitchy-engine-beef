using System;
using System.IO;
using System.Collections;
using GlitchyEngine.Core;
using GlitchyEngine.Content;

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

	public enum ShaderType
	{
		Unknown,
		Vertex,
		Pixel
	}

	// TODO: We may not even need the distinction between shader types anymore (maybe just as an enum)
	public abstract class
		Shader : RefCounter
	{
		protected internal BufferCollection _buffers ~ _.ReleaseRef();//:append _;

		protected ShaderTextureCollection _textures ~ delete _;

		protected ShaderType _shaderType;

		public BufferCollection Buffers => _buffers;

		public ShaderTextureCollection Textures => _textures;

		public ShaderType ShaderType => _shaderType;

		public this()
		{
			_buffers = new BufferCollection();
			_textures = new ShaderTextureCollection();
		}

		public static Result<Shader> CreateFromBlob(Span<uint8> shaderBlob, ShaderType shaderType)
		{
			Debug.Profiler.ProfileResourceFunction!();

			Shader shader = null;

			defer
			{
				if (@return case .Err)
				{
					shader?.ReleaseRef();
				}
			}

			switch (shaderType)
			{
			case .Vertex:
				shader = new VertexShader();
			case .Pixel:
				shader = new PixelShader();
			default:
				Log.EngineLogger.Error($"Can't create shader of type {shaderType}");
				return .Err;
			}

			shader._shaderType = shaderType;

			Try!(shader.InternalCreateFromBlob(shaderBlob));

			return shader;
		}

		public ~this()
		{
			Debug.Profiler.ProfileResourceFunction!();
		}

		protected abstract Result<void> InternalCreateFromBlob(Span<uint8> blob);
	}
}
