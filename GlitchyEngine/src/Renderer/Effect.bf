using System;
using System.IO;
using System.Collections;

namespace GlitchyEngine.Renderer
{
	public class EffectLibrary
	{
		private GraphicsContext _context ~ _?.ReleaseRef();
		private Dictionary<String, Effect> _effects = new .() ~ delete _;

		private List<String> _ownedStrings = new .() ~ DeleteContainerAndItems!(_);

		public this(GraphicsContext context)
		{
			_context = context..AddRef();
		}

		public ~this()
		{
			for(let pair in _effects)
			{
				pair.value.ReleaseRef();
			}
		}

		public void Add(Effect effect, String effectName = null)
		{
			String name;

			if(effectName == null)
			{
				name = effect.Name;
			}
			else
			{
				name = new String(effectName);
				_ownedStrings.Add(name);
			}

			Log.EngineLogger.AssertDebug(!Exists(name), "Can't add two effects with the same name to library.");

			_effects.Add(name, effect..AddRef());
		}

		/**
		 * Loads the effect with the given file name.
		 * @param filepath The path to the effect file.
		 * @param effectName The optional custom effect name which will be used to identify the effect.
		 * @returns The loaded Effect. Note: This function will increment the reference counter of the effect, so the programmer must decrement it once it's not used anymore.
		 *			If the return-value is not needed, use LoadNoRefInc instead.
		 */
		public Effect Load(String filepath, String effectName = null)
		{
			String name = effectName;

			if(name == null)
			{
				name = scope:: String();
				Path.GetFileNameWithoutExtension(filepath, name);
			}
			
			Log.EngineLogger.AssertDebug(!Exists(name), "Can't add two effects with the same name to library.");

			Effect effect = new Effect(_context, filepath, name);
			Add(effect);

			return effect;
		}

		/**
		 * Loads the effect with the given file name.
		 * @param filepath The path to the effect file.
		 * @param effectName The optional custom effect name which will be used to identify the effect.
		 */
		public void LoadNoRefInc(String filepath, String effectName = null)
		{
			var v = Load(filepath, effectName);
			v.ReleaseRef();
		}

		public Effect Get(String effectName)
		{
			Log.EngineLogger.AssertDebug(Exists(effectName), "Effect not found!");

			return _effects.GetValue(effectName).Get()..AddRef();
		}

		public bool Exists(String effectName) => _effects.ContainsKey(effectName);
	}

	public class Effect : RefCounted
	{
		protected GraphicsContext _context ~ _?.ReleaseRef();
		internal VertexShader _vs ~ _?.ReleaseRef();
		internal PixelShader _ps ~ _?.ReleaseRef();
		protected String _name ~ delete _;

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

		public String Name => _name;

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
		
		public this(GraphicsContext context, String filename, String vsEntry, String psEntry, String shaderName = null)
		{
			_context = context..AddRef();
			CompileFromFile(filename, vsEntry, psEntry);

			if(shaderName == null)
			{
				_name = new String(shaderName);
			}
			else
			{
				_name = new String();
				Path.GetFileNameWithoutExtension(filename, _name);
			}
		}

		public this(GraphicsContext context, String filename, String shaderName = null)
		{
			_context = context..AddRef();
			
			String fileContent = scope String();
			String vsName = scope String();
			String psName = scope String();

			ProcessFile(filename, fileContent, vsName, psName);
			Compile(fileContent, vsName, psName);

			MergeResources();
			
			if(shaderName == null)
			{
				_name = new String();
				Path.GetFileNameWithoutExtension(filename, _name);
			}
			else
			{
				_name = new String(shaderName);
			}
		}

		public this(String shaderName, String vsPath, String vsEntry, String psPath, String psEntry)
		{
			Compile(vsPath, vsEntry, psPath, psEntry);
			
			_name = new String(shaderName);
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
