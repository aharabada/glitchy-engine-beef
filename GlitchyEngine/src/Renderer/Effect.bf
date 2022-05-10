using System;
using System.IO;
using System.Collections;
using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer
{
	public class EffectLibrary
	{
		private Dictionary<String, Effect> _effects = new .() ~ delete _;

		private List<String> _ownedStrings = new .() ~ DeleteContainerAndItems!(_);

		public this()
		{
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
			Debug.Profiler.ProfileResourceFunction!();

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
			Debug.Profiler.ProfileResourceFunction!();

			String name = effectName;

			if(name == null)
			{
				name = scope:: String();
				Path.GetFileNameWithoutExtension(filepath, name);
			}
			
			Log.EngineLogger.AssertDebug(!Exists(name), "Can't add two effects with the same name to library.");

			Effect effect = new Effect(filepath, name);
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
			Debug.Profiler.ProfileResourceFunction!();

			Log.EngineLogger.AssertDebug(Exists(effectName), "Effect not found!");

			return _effects.GetValue(effectName).Get()..AddRef();
		}

		public bool Exists(String effectName) => _effects.ContainsKey(effectName);
	}

	public class Effect : RefCounter
	{
		internal VertexShader _vs ~ _?.ReleaseRef();
		internal PixelShader _ps ~ _?.ReleaseRef();
		protected String _name ~ delete _;

		typealias VariableDesc = Dictionary<String, Dictionary<String, Variant>>;

		protected VariableDesc _variableDescriptions ~ {
			for (var (key, value) in _)
			{
				delete key;

				for (var (entryKey, entry) in value)
				{
					delete entryKey;
					entry.Dispose();
				}

				delete value;
			}

			delete _;
		};

		BufferCollection _bufferCollection ~ delete _;

		BufferVariableCollection _variables ~ delete _;
		
		typealias TextureEntry = (Texture Texture, ShaderTextureCollection.ResourceEntry* VsSlot, ShaderTextureCollection.ResourceEntry* PsSlot);
		Dictionary<String, TextureEntry> _textures ~ delete _;

		public Dictionary<String, TextureEntry> Textures => _textures;

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

		[Obsolete("Will be removed in the future", false)]
		public this()
		{
		}
		
		public this(String filename, String vsEntry, String psEntry, String shaderName = null)
		{
			Debug.Profiler.ProfileResourceFunction!();

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

		public this(String filename, String shaderName = null)
		{
			Debug.Profiler.ProfileResourceFunction!();

			String fileContent = scope String();
			String vsName = scope String();
			String psName = scope String();

			_variableDescriptions = new VariableDesc();

			ProcessFile(filename, fileContent, vsName, psName, _variableDescriptions);

			Compile(fileContent, filename, vsName, psName);

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
			Debug.Profiler.ProfileResourceFunction!();

			Compile(vsPath, vsEntry, psPath, psEntry);
			
			_name = new String(shaderName);
		}

		public ~this()
		{
			Debug.Profiler.ProfileResourceFunction!();

			for(let entry in _textures)
			{
				entry.value.Texture?.ReleaseRef();
			}
		}

		public void SetTexture(String name, Texture texture)
		{
			Debug.Profiler.ProfileRendererFunction!();

			ref TextureEntry entry = ref _textures[name];

			entry.Texture?.ReleaseRef();
			entry.Texture = texture;
			entry.Texture?.AddRef();
		}

		private void ApplyTextures()
		{
			Debug.Profiler.ProfileRendererFunction!();

			for(let (name, entry) in _textures)
			{
				entry.VsSlot?.Texture?.ReleaseRef();
				entry.VsSlot?.Texture = entry.Texture;
				entry.VsSlot?.Texture?.AddRef();
				
				entry.PsSlot?.Texture?.ReleaseRef();
				entry.PsSlot?.Texture = entry.Texture;
				entry.PsSlot?.Texture?.AddRef();
			}
		}

		private void ApplyChanges()
		{
			Debug.Profiler.ProfileRendererFunction!();

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
			Debug.Profiler.ProfileRendererFunction!();

			ApplyTextures();
			ApplyChanges();

			context.SetVertexShader(_vs);
			context.SetPixelShader(_ps);
		}



		private void CompileFromFile(String filename, String vsEntry, String psEntry)
		{
			Debug.Profiler.ProfileResourceFunction!();

			let vs = Shader.FromFile!<VertexShader>(filename, vsEntry);
			VertexShader = vs;
			vs.ReleaseRef();
			let ps = Shader.FromFile!<PixelShader>(filename, psEntry);
			PixelShader = ps;
			ps.ReleaseRef();
		}

		private void Compile(String fileContent, String fileName, String vsEntry, String psEntry)
		{
			Debug.Profiler.ProfileResourceFunction!();

			// TODO: vsEntry and psEntry could be empty (which is a valid case.)
			let vs = new VertexShader(fileContent, (StringView)fileName, vsEntry);
			VertexShader = vs;
			vs.ReleaseRef();
			let ps = new PixelShader(fileContent, (StringView)fileName, psEntry);
			PixelShader = ps;
			ps.ReleaseRef();
		}

		const String effectKeyword = "#effect";
		
		private static void CommentLine(StringView code, int commentPosition)
		{
			code[commentPosition] = '/';
			code[commentPosition + 1] = '/';
		}

		/**
		 * Loads the effect file and extracts the names of the vertex- and pixel-shader.
		 * @param filename The path of the effect file.
		 * @param fileContent The preprocessed effect file.
		 * @param outVsName The string that will receive the vertex shader entry point.
		 * @param outPsName The string that will receive the pixel shader entry point.
		 * @param outVarDescs The dictionary that will contain the Variable descriptions.
		 */
		private static void ProcessFile(String filename, String fileContent, String outVsName, String outPsName, VariableDesc outVarDescs)
		{
			Debug.Profiler.ProfileResourceFunction!();

			File.ReadAllText(filename, fileContent, true);
			// append line ending just in case the file doesn't end with one.
			fileContent.Append('\n');

			ProcessEditorVariables(filename, fileContent, outVarDescs);

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
					outVsName.Append(paramValue);
				case "PS", "PixelShader":
					outPsName.Append(paramValue);
				default:
					Log.EngineLogger.Assert(false, scope $"Unknown parameter name \"{paramName}\".");
				}
			}

			// remove preprocessor directive from string so that the compiler wont try process it
			CommentLine(fileContent, effectIndex);
		}

		private static void ProcessEditorVariables(StringView fileName, StringView code, VariableDesc outVarDescs)
		{
			int index = 0;

			while(true)
			{
				index = code.IndexOf("#EditorVariable", index);

				if (index == -1)
					break;
				
				CommentLine(code, index);

				index = code.IndexOf('{', index);

				Log.EngineLogger.AssertDebug(index != -1, "Missing '{'.");

				index++;

				int endIndex = code.IndexOf('}', index);
				
				Log.EngineLogger.AssertDebug(endIndex != -1, "Missing '}'.");

				StringView variableInfo = StringView(code, index, endIndex - index);

				Log.ClientLogger.Info($"Found variable: \"{variableInfo}\"");

				Dictionary<String, Variant> parameters = new .();

				String variableName = null;

				for (StringView argument in variableInfo.Split(';', .RemoveEmptyEntries))
				{
					int equalsIndex = argument.IndexOf('=');

					if (equalsIndex == -1)
					{
						Log.EngineLogger.Error($"Missing value for Argument \"{argument..Trim()}\".");
					}
					else
					{
						StringView argName = argument.Substring(0, equalsIndex)..Trim();
						StringView argValue = argument.Substring(equalsIndex + 1)..Trim();

						if (argValue.StartsWith('"') && argValue.EndsWith('"'))
						{
							argValue = argValue[1...^2];
						}	

						if (argName == "Name")
							variableName = new String(argValue);
						else
						{
							Variant value;

							if (argName == "Min" || argName == "Max")
							{
								value = ParseVariableValue(argValue);
							}
							else
							{
								value = Variant.Create(new String(argValue), true);
							}

							parameters.Add(new String(argName), value);
						}
					}
				}

				Log.EngineLogger.AssertDebug(variableName != null, "Missing argument \"Name\" int variable description.");

				outVarDescs.Add(variableName, parameters);

				index = endIndex;
			}
		}

		private static Variant ParseVariableValue(StringView valueString)
		{
			if (valueString[0].IsDigit || valueString[0] == '-')
			{
				var valueString;

				if (valueString.EndsWith('f'))
					valueString.Length--;

				var result = float.Parse(valueString);

				Log.EngineLogger.AssertDebug(result case .Ok);

				if (result case .Ok(let value))
					return Variant.Create(value);
			}
			else if (valueString.StartsWith("float"))
			{
				int index = 5;

				int numComponents = valueString[index++] - '0';

				while (valueString[index] != '(')
				{
					Log.EngineLogger.AssertDebug(valueString[index].IsWhiteSpace, "Expected '('.");

					index++;
				}

				Log.EngineLogger.AssertDebug(numComponents >= 2 && numComponents <= 4, scope $"Unsupported component count {numComponents}. Value must be between 2 and 4");

				float[] floats = scope float[numComponents];

				for (int i < numComponents)
				{
					while (true)
					{
						char8 c = valueString[++index];

						if (c.IsDigit || c == '.' || c == '-')
							break;
					}

					int start = index;

					while (true)
					{
						char8 c = valueString[++index];

						if (!c.IsDigit && c != '.')
							break;
					}

					int end = index;

					StringView numberView = .(valueString, start, end - start);
					
					var result = float.Parse(numberView);

					if (result case .Ok(let value))
					{
						floats[i] = value;
					}
				}

				if (numComponents == 2)
					return Variant.Create(*(Vector2*)floats.Ptr);
				else if (numComponents == 3)
					return Variant.Create(*(Vector3*)floats.Ptr);
				else if (numComponents == 4)
					return Variant.Create(*(Vector4*)floats.Ptr);
			}
			else
			{
				Log.EngineLogger.Error($"Unsupported variable value: \"{valueString}\"");
			}

			return Variant.Create(0.0f);
		}

		//protected extern void Compile(String code, String fileName, String vsEntry, String psEntry);

		private void MergeResources()
		{
			Debug.Profiler.ProfileResourceFunction!();

			MergeConstantBuffers();
			MergeBufferVariables();
			MergeTextures();
		}

		private void MergeConstantBuffers()
		{
			Debug.Profiler.ProfileResourceFunction!();

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
			Debug.Profiler.ProfileResourceFunction!();

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
			Debug.Profiler.ProfileResourceFunction!();

			if(shader != null)
			{
				for(let buffer in shader.Buffers)
				{
					bufferNames.Add(buffer.Name);
				}
			}
		}

		/// Merges the texture slots of all shaders into one dictionary.
		private void MergeTextures()
		{
			Debug.Profiler.ProfileResourceFunction!();

			delete _textures;
			_textures = new .();

			EnumerateShaderTextures(_vs);
			EnumerateShaderTextures(_ps);
		}

		/** @brief Merges all textures of the given shader into the _textures dictionary.
		 * @param shader The shader whose textures will be merged into the dictionary.
		 */
		private void EnumerateShaderTextures<T>(T shader) where T : Shader
		{
			Debug.Profiler.ProfileResourceFunction!();

			//for(var (name, index, texture) in shader.Resources)
			for(var shaderEntry in ref shader.Textures)
			{
				TextureEntry entry;

				// Get existing entry or create new
				if(!_textures.TryGetValue(shaderEntry.Name, out entry))
				{
					entry = (shaderEntry.Texture, null, null);
					entry.Texture?.AddRef();
				}

				// Set the corresponding shader resource slot
				if(typeof(T) == typeof(VertexShader))
				{
					entry.VsSlot = &shaderEntry;
				}
				else if(typeof(T) == typeof(PixelShader))
				{
					entry.PsSlot = &shaderEntry;
				}

				// If the entry has no texture but the shader has one -> set texture
				if(entry.Texture == null && shaderEntry.Texture != null)
				{
					entry.Texture = shaderEntry.Texture;
					entry.Texture?.AddRef();
				}

				// save entry
				_textures[shaderEntry.Name] = entry;
			}
		}
	}
}
