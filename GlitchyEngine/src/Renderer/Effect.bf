using System;
using System.IO;
using System.Collections;
using GlitchyEngine.Core;
using GlitchyEngine.Math;
using GlitchyEngine.Content;

namespace GlitchyEngine.Renderer;

/*/// Obsolete because of the ContentManager?
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

		if (Exists(name))
		{
			return Get(name);
		}
		else
		{
			Log.EngineLogger.AssertDebug(!Exists(name), "Can't add two effects with the same name to library.");

			Effect effect = new Effect(filepath, name);
			Add(effect);

			return effect;
		}
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
}*/

public enum TextureDimension
{
	Unknown,
	Texture1D,
	Texture1DArray,
	Texture2D,
	Texture2DArray,
	Texture3D,
	TextureCube,
	TextureCubeArray
}

public class Effect : Asset
{
	internal VertexShader _vs ~ _?.ReleaseRef();
	internal PixelShader _ps ~ _?.ReleaseRef();

	typealias VariableDesc = Dictionary<String, Dictionary<String, Variant>>;

	protected VariableDesc _variableDescriptions = new .() ~ {
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

	protected Dictionary<String, String> _engineBuffers = new .() ~ DeleteDictionaryAndKeysAndValues!(_);

	BufferCollection _bufferCollection ~ _.ReleaseRef();

	BufferVariableCollection _variables ~ delete _;

	public struct TextureEntry
	{
		public TextureViewBinding BoundTexture;
		public TextureDimension TextureDimension;
		public ShaderTextureCollection.ResourceEntry* VsSlot;
		public ShaderTextureCollection.ResourceEntry* PsSlot;

		public this(TextureViewBinding boundTexture, TextureDimension textureDimension, ShaderTextureCollection.ResourceEntry* vsSlot, ShaderTextureCollection.ResourceEntry* psSlot)
		{
			BoundTexture = boundTexture;
			VsSlot = vsSlot;
			PsSlot = psSlot;
			TextureDimension = textureDimension;
		}
	}

	Dictionary<String, TextureEntry> _textures ~ delete _;

	public Dictionary<String, TextureEntry> Textures => _textures;

	public VertexShader VertexShader
	{
		get => _vs;
		private set => SetReference!(_vs, value);
	}
	
	public PixelShader PixelShader
	{
		get => _ps;
		private set => SetReference!(_ps, value);
	}

	public BufferCollection Buffers => _bufferCollection;
	public BufferVariableCollection Variables => _variables;

	[Obsolete("", false)]
	public this(String filename)
	{
		Debug.Profiler.ProfileResourceFunction!();

		String fileContent = scope String();
		String vsName = scope String();
		String psName = scope String();

		ProcessFile(filename, fileContent, vsName, psName, _variableDescriptions, _engineBuffers);

		Compile(fileContent, filename, vsName, psName);

		MergeResources();
	}

	public this(Stream data, StringView assetIdentifier, IContentManager contentManager)
	{
		Debug.Profiler.ProfileResourceFunction!();

		String fileContent = scope String();
		String vsName = scope String();
		String psName = scope String();

		ProcessStream(data, fileContent, vsName, psName, _variableDescriptions, _engineBuffers);

		Compile(fileContent, assetIdentifier, vsName, psName, contentManager);

		MergeResources();
	}

	public ~this()
	{
		Debug.Profiler.ProfileResourceFunction!();

		for(let entry in _textures)
		{
			entry.value.BoundTexture.Release();
		}
	}

	public void SetTexture(String name, Texture texture)
	{
		Debug.Profiler.ProfileRendererFunction!();

		if (texture == null)
			return;

		[Inline]InternalSetTexture(name, texture.GetViewBinding());
	}
	
	public void SetTexture(String name, RenderTargetGroup renderTargetGroup, int32 firstTarget, uint32 targetCount = 1)
	{
		Debug.Profiler.ProfileRendererFunction!();

		if (targetCount != 1)
			Runtime.NotImplemented("Binding multiple rendertargets to a slot is not yet implemented.");

		// We have to release the viewBinding because GetViewBinding internally increases the counter
		[Inline]InternalSetTexture(name, renderTargetGroup.GetViewBinding(firstTarget));
	}

	public void SetTexture(String name, TextureViewBinding textureViewBinding)
	{
		Debug.Profiler.ProfileRendererFunction!();

		[Inline]InternalSetTexture(name, textureViewBinding..AddRef());
	}

	private void InternalSetTexture(String name, TextureViewBinding textureViewBinding)
	{
		Debug.Profiler.ProfileRendererFunction!();

		ref TextureEntry entry = ref _textures[name];

		entry.BoundTexture.Release();
		entry.BoundTexture = textureViewBinding;

		entry.VsSlot?.BoundTexture..Release() = entry.BoundTexture..AddRef();
		entry.PsSlot?.BoundTexture..Release() = entry.BoundTexture..AddRef();
	}

	/*private void ApplyTextures()
	{
		Debug.Profiler.ProfileRendererFunction!();

		for(let (name, entry) in _textures)
		{
			entry.VsSlot?.BoundTexture.Release();
			entry.VsSlot?.BoundTexture = entry.BoundTexture;
			entry.VsSlot?.BoundTexture.AddRef();
			
			entry.PsSlot?.BoundTexture.Release();
			entry.PsSlot?.BoundTexture = entry.BoundTexture;
			entry.PsSlot?.BoundTexture.AddRef();
		}
	}*/

	public void ApplyChanges()
	{
		Debug.Profiler.ProfileRendererFunction!();
		
		//ApplyTextures();

		for(let buffer in _bufferCollection)
		{
			if(let cbuffer = buffer.Buffer as ConstantBuffer)
			{
				cbuffer.Update();
			}
		}
	}

	public void Bind()
	{
		Debug.Profiler.ProfileRendererFunction!();

		//ApplyTextures();
		//ApplyChanges();

		RenderCommand.BindVertexShader(_vs);
		RenderCommand.BindPixelShader(_ps);
	}

	/*private void CompileFromFile(String filename, String vsEntry, String psEntry)
	{
		Debug.Profiler.ProfileResourceFunction!();

		let vs = Shader.FromFile!<VertexShader>(filename, vsEntry);
		VertexShader = vs;
		vs.ReleaseRef();
		let ps = Shader.FromFile!<PixelShader>(filename, psEntry);
		PixelShader = ps;
		ps.ReleaseRef();
	}*/

	private void Compile(String fileContent, StringView fileName, String vsEntry, String psEntry, IContentManager contentManager = null)
	{
		Debug.Profiler.ProfileResourceFunction!();

		// TODO: vsEntry and psEntry could be empty (which is a valid case.)
		let vs = new VertexShader(fileContent, fileName, vsEntry, contentManager);
		VertexShader = vs;
		vs.ReleaseRef();
		let ps = new PixelShader(fileContent, fileName, psEntry, contentManager);
		PixelShader = ps;
		ps.ReleaseRef();
	}

	const String effectKeyword = "#effect";
	
	private static void CommentLine(StringView code, int commentPosition)
	{
		code[commentPosition] = '/';
		code[commentPosition + 1] = '/';
	}

	private static Result<(int Start, int End)> GetNextPreprocessor(StringView code, int startindex, out StringView name, Dictionary<StringView, StringView> arguments)
	{
		name = .();

		int startOfLine;
		int endOfLine;
		do
		{
			startOfLine = code.IndexOf("#pragma", startindex);

			if (startOfLine == -1)
				return .Err;

			endOfLine = code.IndexOf('\n', startOfLine);

			StringView line = (endOfLine != -1) ? code.Substring(startOfLine, endOfLine - startOfLine) : code.Substring(startOfLine);

			// cut off the #pragma
			line = line.Substring(7);

			int lBracketIndex = line.IndexOf('[');

			if (lBracketIndex == -1)
			{
				name = line..Trim();
				break;
			}

			name = line.Substring(0, lBracketIndex);
			name.Trim();
			
			int rBracketIndex = line.IndexOf(']');

			if (rBracketIndex == -1)
			{
				Log.EngineLogger.Error($"Pragma is missing closing Bracket (\"{line}\")");
				rBracketIndex = line.Length;
			}

			StringView argumentText = line.Substring(lBracketIndex + 1, rBracketIndex - lBracketIndex - 1);

			for (StringView argument in argumentText.Split(';'))
			{
				int equalsIndex = argument.IndexOf('=');

				StringView argumentName = .();
				StringView argumentValue = .();

				if (equalsIndex == -1)
				{
					argumentName = argument;
					argumentName.Trim();
				}
				else
				{
					argumentName = argument.Substring(0, equalsIndex);
					argumentName.Trim();

					argumentValue = argument.Substring(equalsIndex + 1);
					argumentValue.Trim();
				}

				if (arguments.ContainsKey(argumentName))
				{
					Log.EngineLogger.Error($"Arguments \"{argumentName}\" already exists.");
					continue;
				}

				arguments.Add(argumentName, argumentValue);
			}
		}

		return .Ok((startOfLine, endOfLine));
	}

	private static void ProcessStream(Stream rawData, String fileContent, String outVsName, String outPsName, VariableDesc outVarDescs, Dictionary<String, String> outEngineBuffers)
	{
		Debug.Profiler.ProfileResourceFunction!();

		StreamReader streamReader = scope .(rawData);
		streamReader.ReadToEnd(fileContent);
		// append line ending just in case the file doesn't end with one.
		fileContent.Append('\n');
		
		ProcessFileContent(fileContent, outVsName, outPsName, outVarDescs, outEngineBuffers);
	}

	/**
	 * Loads the effect file and extracts the names of the vertex- and pixel-shader.
	 * @param filename The path of the effect file.
	 * @param fileContent The preprocessed effect file.
	 * @param outVsName The string that will receive the vertex shader entry point.
	 * @param outPsName The string that will receive the pixel shader entry point.
	 * @param outVarDescs The dictionary that will contain the Variable descriptions.
	 */
	private static void ProcessFile(String filename, String fileContent, String outVsName, String outPsName, VariableDesc outVarDescs, Dictionary<String, String> outEngineBuffers)
	{
		Debug.Profiler.ProfileResourceFunction!();

		File.ReadAllText(filename, fileContent, true);
		// append line ending just in case the file doesn't end with one.
		fileContent.Append('\n');

		ProcessFileContent(fileContent, outVsName, outPsName, outVarDescs, outEngineBuffers);
	}

	private static void ProcessFileContent(String fileContent, String outVsName, String outPsName, VariableDesc outVarDescs, Dictionary<String, String> outEngineBuffers)
	{
		Debug.Profiler.ProfileResourceFunction!();

		Dictionary<StringView, StringView> arguments = scope .();

		int index = 0;

		while (true)
		{
			Result<(int Start, int End)> result = GetNextPreprocessor(fileContent, index, let name, arguments..Clear());

			if (result case .Err)
				break;
			else if (result case .Ok(let value))
			{
				index = value.End;

				switch(name)
				{
				case "Effect":
					for (let (argName, argValue) in arguments)
					{
						switch(argName)
						{
						case "VS", "VertexShader":
							outVsName.Append(argValue);
						case "PS", "PixelShader":
							outPsName.Append(argValue);
						default:
							Log.EngineLogger.Assert(false, scope $"Unknown parameter name \"{name}\".");
						}
					}
				case "EditorVariable":
					ProcessEditorVariables(arguments, outVarDescs);
				case "EngineBuffer":
					ProcessEngineBuffer(arguments, outEngineBuffers);
				default:
					continue;
				}

				CommentLine(fileContent, value.Start);
			}
		}
	}

	private static void ProcessEngineBuffer(Dictionary<StringView, StringView> arguments, Dictionary<String, String> outEngineBuffers)
	{
		String nameInEngine = null;
		String nameInShader = null;

		for (var (argName, argValue) in arguments)
		{
			if (argValue.StartsWith('"') && argValue.EndsWith('"'))
			{
				argValue = argValue[1...^2];
			}
			switch (argName)
			{
			case "Name":
				nameInShader = new String(argValue);
			case "Binding":
				nameInEngine = new String(argValue);
			default:
				Log.EngineLogger.Assert(false, scope $"Unknown parameter for EngineBuffer: \"{argName}\".");
			}
		}

		Log.EngineLogger.AssertDebug(nameInEngine != null);
		Log.EngineLogger.AssertDebug(nameInShader != null);

		outEngineBuffers.Add(nameInEngine, nameInShader);
	}

	private static void ProcessEditorVariables(Dictionary<StringView, StringView> arguments, VariableDesc outVarDescs)
	{
		String variableName = null;
		
		Dictionary<String, Variant> parameters = new .();

		for (var (name, value) in arguments)
		{
			if (value.StartsWith('"') && value.EndsWith('"'))
			{
				value = value[1...^2];
			}

			switch(name)
			{
			case "Name":
				variableName = new String(value);
			case "Min", "Max":
				Variant paramValue = ParseVariableValue(value);
				parameters.Add(new String(name), paramValue);
			default:
				Variant paramValue = Variant.Create(new String(value), true);
				parameters.Add(new String(name), paramValue);
			}
		}
		
		Log.EngineLogger.AssertDebug(variableName != null, "Missing argument \"Name\" int variable description.");

		outVarDescs.Add(variableName, parameters);

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
				return Variant.Create(*(float2*)floats.Ptr);
			else if (numComponents == 3)
				return Variant.Create(*(float3*)floats.Ptr);
			else if (numComponents == 4)
				return Variant.Create(*(float4*)floats.Ptr);
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

		SetReference!(_vs.[Friend]_buffers, _bufferCollection);
		SetReference!(_ps.[Friend]_buffers, _bufferCollection);
	}

	private void MergeBufferVariables()
	{
		Debug.Profiler.ProfileResourceFunction!();

		_variables = new BufferVariableCollection(false);

		outer: for(let buffer in _bufferCollection)
		{
			for (let eb in _engineBuffers)
			{
				if (eb.value == buffer.Name)
				{
					continue outer;
				}
			}

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
				entry = .(shaderEntry.BoundTexture, shaderEntry.Dimension, null, null);
				entry.BoundTexture.AddRef();
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
			if(entry.BoundTexture.IsEmpty && !shaderEntry.BoundTexture.IsEmpty)
			{
				entry.BoundTexture = shaderEntry.BoundTexture;
				entry.BoundTexture.AddRef();
			}

			// save entry
			_textures[shaderEntry.Name] = entry;
		}
	}
}
