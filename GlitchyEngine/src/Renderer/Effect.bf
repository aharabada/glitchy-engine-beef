using System;
using System.IO;
using System.Collections;

namespace GlitchyEngine.Renderer
{
	public class Effect : RefCounted
	{
		protected GraphicsContext _context ~ _?.ReleaseRef();
		internal VertexShader _vs ~ _?.ReleaseRef();
		internal PixelShader _ps ~ _?.ReleaseRef();

		BufferCollection _bufferCollection ~ delete _;

		BufferVariableCollection _variables ~ delete _;

		public GraphicsContext Context => _context;

		public VertexShader VertexShader
		{
			get => _vs;
			set
			{
				_vs?.ReleaseRef();
				_vs = value;
				_vs?.AddRef();
			}
		}
		
		public PixelShader PixelShader
		{
			get => _ps;
			set
			{
				_ps?.ReleaseRef();
				_ps = value;
				_ps?.AddRef();
			}
		}

		public BufferCollection Buffers => _bufferCollection;
		public BufferVariableCollection Variables => _variables;

		public void ApplyChanges()
		{
			for(let buffer in _bufferCollection)
			{
				if(let cbuffer = buffer.Buffer as ConstantBuffer)
				{
					cbuffer.Update();
				}
			}
		}

		public void Bind(GraphicsContext context)
		{
			ApplyChanges();

			context.SetVertexShader(_vs);
			context.SetPixelShader(_ps);
		}

		[Obsolete("Will be removed in the future", false)]
		public this()
		{
		}
		
		public this(GraphicsContext context, String filename, String vsEntry, String psEntry)
		{
			_context = context..AddRef();
			CompileFromFile(filename, vsEntry, psEntry);
		}

		public this(GraphicsContext context, String filename)
		{
			_context = context..AddRef();
			
			String fileContent = scope String();
			String vsName = scope String();
			String psName = scope String();

			ProcessFile(filename, fileContent, vsName, psName);
			Compile(fileContent, vsName, psName);

			MergeResources();
		}

		public this(String vsPath, String vsEntry, String psPath, String psEntry)
		{
			Compile(vsPath, vsEntry, psPath, psEntry);
		}

		private void CompileFromFile(String filename, String vsEntry, String psEntry)
		{
			let vs = Shader.FromFile!<VertexShader>(_context, filename, vsEntry);
			VertexShader = vs;
			vs.ReleaseRef();
			let ps = Shader.FromFile!<PixelShader>(_context, filename, psEntry);
			PixelShader = ps;
			ps.ReleaseRef();
		}

		private void Compile(String fileContent, String vsEntry, String psEntry)
		{
			// TODO: vsEntry and psEntry could be empty (which is a valid case.)
			let vs = new VertexShader(_context, fileContent, vsEntry);
			VertexShader = vs;
			vs.ReleaseRef();
			let ps = new PixelShader(_context, fileContent, psEntry);
			PixelShader = ps;
			ps.ReleaseRef();
		}

		const String effectKeyword = "#effect";

		/**
		 * Loads the effect file and extracts the names of the vertex- and pixel-shader.
		 * @param filename The path of the effect file.
		 * @param fileContent The preprocessed effect file.
		 * @param vsName The string that will receive the vertex shader entry point.
		 * @param psName The string that will receive the pixel shader entry point.
		 */
		private static void ProcessFile(String filename, String fileContent, String vsName, String psName)
		{
			File.ReadAllText(filename, fileContent, true);
			// append line ending just in case the file doesn't end with one.
			fileContent.Append('\n');

			int effectIndex = fileContent.IndexOf(effectKeyword, true);

			Log.EngineLogger.Assert(effectIndex >= 0, "Could not find #effect preprocessor directive.");

			int lineEndIndex = fileContent.IndexOf('\n', effectIndex + effectKeyword.Length);

			// String containing the #effect directive
			StringView effectDirective = fileContent.Substring(effectIndex, lineEndIndex - effectIndex);

			int paramStartIndex = effectDirective.IndexOf('[');

			Log.EngineLogger.Assert(paramStartIndex >= 0, "Expected '[' after \"#effect\"");

			StringView effectToBracket = effectDirective.Substring(effectKeyword.Length, paramStartIndex - effectKeyword.Length);

			// Make sure there is only whitespace between "#effect" and "["
			Log.EngineLogger.Assert(effectToBracket.IsWhiteSpace, "Expected '[' after \"#effect\"");
			
			int paramEndIndex = effectDirective.IndexOf(']');

			Log.EngineLogger.Assert(paramEndIndex >= 0, "Expected ']'");

			StringView parameters = effectDirective.Substring(paramStartIndex + 1, paramEndIndex - paramStartIndex - 1);

			for(StringView parameter in parameters.Split(','))
			{
				int indexOfEquals = parameter.IndexOf("=");

				Log.EngineLogger.Assert(indexOfEquals >= 0, "Expected '='");

				StringView paramName = parameter.Substring(0, indexOfEquals);
				paramName.Trim();

				StringView paramValue = parameter.Substring(indexOfEquals + 1);
				paramValue.Trim();

				switch(paramName)
				{
				case "VS", "VertexShader":
					vsName.Append(paramValue);
				case "PS", "PixelShader":
					psName.Append(paramValue);
				default:
					Log.EngineLogger.Assert(false, scope $"Unknown parameter name \"{paramName}\".");
				}
			}

			// remove preprocessor directive from string so that the compiler wont try process it
			fileContent.Remove(effectIndex, lineEndIndex - effectIndex);
		}

		protected extern void Compile(String vsPath, String vsEntry, String psPath, String psEntry);

		private void MergeResources()
		{
			MergeConstantBuffers();
			MergeBufferVariables();
		}

		private void MergeConstantBuffers()
		{
			_bufferCollection = new BufferCollection();

			HashSet<String> bufferNames = scope HashSet<String>();

			AddShaderBuffers(_vs, bufferNames);
			AddShaderBuffers(_ps, bufferNames);

			int internalIndex = 0;

			for(String bufferName in bufferNames)
			{
				let vsBuffer = _vs.Buffers.TryGetBufferEntry(bufferName);
				let psBuffer = _ps.Buffers.TryGetBufferEntry(bufferName);

				if(vsBuffer != null && psBuffer != null)
				{
					BufferCollection.BufferEntry* fxBuffer = null;
					// choose the larger of the two
					if(psBuffer.Buffer.Description.Size > vsBuffer.Buffer.Description.Size)
						fxBuffer = psBuffer;
					else
						fxBuffer = vsBuffer;

					_bufferCollection.Add(internalIndex, bufferName, fxBuffer.Buffer);

					_vs.Buffers.TryReplaceBuffer(vsBuffer.Index, fxBuffer.Buffer);
					_ps.Buffers.TryReplaceBuffer(psBuffer.Index, fxBuffer.Buffer);
				}
				else if(vsBuffer != null)
				{
					_bufferCollection.Add(internalIndex, bufferName, vsBuffer.Buffer);
				}
				else if(psBuffer != null)
				{
					_bufferCollection.Add(internalIndex, bufferName, psBuffer.Buffer);
				}

				internalIndex++;
			}
		}

		private void MergeBufferVariables()
		{
			_variables = new BufferVariableCollection(false);

			for(let buffer in _bufferCollection)
			{
				if(let cbuffer = buffer.Buffer as ConstantBuffer)
				{
					for(let variable in	cbuffer.Variables)
					{
						_variables.TryAdd(variable);
					}
				}
			}
		}

		private void AddShaderBuffers(Shader shader, HashSet<String> bufferNames)
		{
			if(shader != null)
			{
				for(let buffer in shader.Buffers)
				{
					bufferNames.Add(buffer.Name);
				}
			}
		}
	}
}
