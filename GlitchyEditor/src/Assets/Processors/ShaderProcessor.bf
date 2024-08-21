using GlitchyEditor.Assets.Importers;
using System;
using GlitchyEngine.Content;
using System.Collections;
using GlitchyEngine;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;

namespace GlitchyEditor.Assets.Processors;

class ProcessedShader : ProcessedResource
{
	public struct TextureEntry
	{
		public StringView Name;
		public TextureDimension TextureDimension;
		public int32 VertexShaderBindPoint;
		public int32 PixelShaderBindPoint;

		public static readonly TextureEntry Default = .() {
			Name = null,
			TextureDimension = .Unknown,
			VertexShaderBindPoint = -1,
			PixelShaderBindPoint = -1
		};
	}

	public struct ConstantBufferEntry
	{
		public ReflectedConstantBuffer ConstantBuffer;
		public int32 VertexShaderBindPoint;
		public int32 PixelShaderBindPoint;

		public static readonly Self Default = .() {
			ConstantBuffer = null,
			VertexShaderBindPoint = -1,
			PixelShaderBindPoint = -1,
		};
	}

	public override AssetType AssetType => .Shader;

	public CompiledShader VertexShader ~ delete _;
	public CompiledShader PixelShader ~ delete _;

	Dictionary<StringView, ConstantBufferEntry> _constantBuffers = new .() ~ delete _; // Only delete container, Buffers come from shaders
	
	Dictionary<StringView, TextureEntry> _textures = new .() ~ delete _;

	public Dictionary<StringView, ConstantBufferEntry> ConstantBuffers => _constantBuffers;
	public Dictionary<StringView, TextureEntry> Textures => _textures;

	public this(AssetIdentifier ownAssetIdentifier, AssetHandle assetHandle) : base(ownAssetIdentifier, assetHandle)
	{

	}

	public void AddConstantBuffer(ConstantBufferEntry buffer)
	{
		_constantBuffers.Add(buffer.ConstantBuffer.Name, buffer);
	}

	public void AddTextureEntry(TextureEntry textureEntry)
	{
		_textures.Add(textureEntry.Name, textureEntry);
	}
}

class ShaderVariable
{
	private String _name ~ delete _;

	private Dictionary<String, Variant> _parameters = new .() ~ {
		for (var (entryKey, entry) in _)
		{
			delete entryKey;
			entry.Dispose();
		}
		delete _;
	};

	public StringView Name
	{
		get => _name;
		set => String.NewOrSet!(_name, value);
	}

	public Dictionary<String, Variant> Parameters => _parameters;

	public void AddParameter(StringView name, Variant value)
	{
		_parameters.Add(new String(name), value);
	}
}

class ShaderProcessor : IAssetProcessor
{
	public AssetProcessorConfig CreateDefaultConfig()
	{
		return new AssetProcessorConfig();
	}

	public static Type ProcessedAssetType => typeof(ImportedShader);

	public Result<void> Process(ImportedResource importedResource, AssetConfig config, List<ProcessedResource> outProcessedResources)
	{
		Log.EngineLogger.AssertDebug(importedResource is ImportedShader);

		Try!(ProcessShader(importedResource as ImportedShader, config, outProcessedResources));

		return default;
	}

	private static Result<void> ProcessShader(ImportedShader importedShader, AssetConfig config, List<ProcessedResource> outProcessedResources)
	{
		String vsName = scope String();
		String psName = scope String();

		Dictionary<StringView, ShaderVariable> variables = scope .();
		List<String> bufferNames = scope .();
		// Name in Shader -> Name in Engine
		Dictionary<StringView, StringView> engineBuffers = scope .();

		defer
		{
			ClearDictionaryAndDeleteValues!(variables);
			ClearAndDeleteItems!(bufferNames);
		}

		String code = new String(importedShader.HlslCode);
		defer { delete code; }

		Try!(ProcessFileContent(code, vsName, psName, variables, bufferNames, engineBuffers));

		if (String.IsNullOrWhiteSpace(vsName) && String.IsNullOrWhiteSpace(psName))
		{
			// this is not an effect -> we don't need to compile it
			return .Ok;
		}

		ProcessedShader processedShader = new ProcessedShader(new AssetIdentifier(importedShader.AssetIdentifier), config.AssetHandle);

		Try!(CompileAndReflect(vsName, psName, importedShader, code, processedShader));

		Try!(MergeResources(processedShader, variables, engineBuffers));

		outProcessedResources.Add(processedShader);

		return .Ok;
	}

	private static Result<void> MergeResources(ProcessedShader processedShader, 
		Dictionary<StringView, ShaderVariable> variables,
		Dictionary<StringView, StringView> engineBuffers)
	{
		Try!(MergeConstantBuffers(processedShader, variables, engineBuffers));
		Try!(MergeTextures(processedShader));

		return .Ok;
	}

	private static Result<void> MergeConstantBuffers(ProcessedShader processedShader, 
		Dictionary<StringView, ShaderVariable> variables,
		Dictionary<StringView, StringView> engineBuffers)
	{
		HashSet<StringView> bufferNames = scope .();

		void AddBufferNames(CompiledShader shader)
		{
			for (StringView name in shader.ConstantBuffers.Keys)
			{
				bufferNames.Add(name);
			}
		}

		AddBufferNames(processedShader.VertexShader);
		AddBufferNames(processedShader.PixelShader);

		for (StringView bufferName in bufferNames)
		{
			Result<ReflectedConstantBuffer> vsBufferResult = processedShader.VertexShader.ConstantBuffers.GetValue(bufferName);
			Result<ReflectedConstantBuffer> psBufferResult = processedShader.PixelShader.ConstantBuffers.GetValue(bufferName);
			
			ProcessedShader.ConstantBufferEntry constantBufferEntry = .Default;

			if (vsBufferResult case .Ok(let vsBuffer) && psBufferResult case .Ok(let psBuffer))
			{
				// Choose larger buffer
				constantBufferEntry.ConstantBuffer = (vsBuffer.Size >= psBuffer.Size) ? vsBuffer : psBuffer;
				constantBufferEntry.VertexShaderBindPoint = (.)vsBuffer.BindPoint;
				constantBufferEntry.PixelShaderBindPoint = (.)psBuffer.BindPoint;
			}
			else if (vsBufferResult case .Ok(let vsBuffer))
			{
				constantBufferEntry.ConstantBuffer = vsBuffer;
				constantBufferEntry.VertexShaderBindPoint = (.)vsBuffer.BindPoint;
			}
			else if (psBufferResult case .Ok(let psBuffer))
			{
				constantBufferEntry.ConstantBuffer = psBuffer;
				constantBufferEntry.PixelShaderBindPoint = (.)psBuffer.BindPoint;
			}

			Log.EngineLogger.Assert(constantBufferEntry.ConstantBuffer != null);
			Log.EngineLogger.Assert(constantBufferEntry.VertexShaderBindPoint > -1 || constantBufferEntry.PixelShaderBindPoint > -1);

			if (engineBuffers.TryGetValue(constantBufferEntry.ConstantBuffer.Name, let engineBufferName))
			{
				constantBufferEntry.ConstantBuffer.EngineBufferName = engineBufferName;
			}

			processedShader.AddConstantBuffer(constantBufferEntry);
		}

		return .Ok;
	}
	
	static ref ProcessedShader.TextureEntry AddOrGetTextureEntry(ProcessedShader processedShader, ReflectedTexture reflectedTexture)
	{
		if (!processedShader.Textures.ContainsKey(reflectedTexture.Name))
		{
			ProcessedShader.TextureEntry textureEntry = .Default;
			textureEntry.Name = reflectedTexture.Name;
			textureEntry.TextureDimension = reflectedTexture.TextureDimension;

			processedShader.Textures.Add(textureEntry.Name, textureEntry);
		}

		ref ProcessedShader.TextureEntry entry = ref processedShader.Textures[reflectedTexture.Name];

		return ref entry;
	}

	private static Result<void> MergeTextures(ProcessedShader processedShader)
	{
		for (let (textureName, reflectedTexture) in processedShader.VertexShader.Textures)
		{
			ref ProcessedShader.TextureEntry textureEntry = ref AddOrGetTextureEntry(processedShader, reflectedTexture);
			textureEntry.VertexShaderBindPoint = (int32)reflectedTexture.BindPoint;
		}

		for (let (textureName, reflectedTexture) in processedShader.PixelShader.Textures)
		{
			ref ProcessedShader.TextureEntry textureEntry = ref AddOrGetTextureEntry(processedShader, reflectedTexture);
			textureEntry.PixelShaderBindPoint = (int32)reflectedTexture.BindPoint;
		}

		return .Ok;
	}

	private static Result<void> CompileAndReflect(StringView vsName, StringView psName, ImportedShader shader, StringView code, ProcessedShader processedShader)
	{
		if (!vsName.IsWhiteSpace)
		{
			processedShader.VertexShader = Try!(CompileAndReflectVertexShader(vsName, shader, code));
		}

		if (!psName.IsWhiteSpace)
		{
			processedShader.PixelShader = Try!(CompileAndReflectPixelShader(psName, shader, code));
		}

		return .Ok;
	}

	private static Result<CompiledShader> CompileAndReflectVertexShader(StringView vsName, ImportedShader importedShader, StringView code)
	{
		Debug.Profiler.ProfileResourceFunction!();

		return ShaderCompiler.CompileAndReflectShader(code, importedShader.AssetIdentifier, vsName, "vs_5_0", .());
	}

	private static Result<CompiledShader> CompileAndReflectPixelShader(StringView vsName, ImportedShader importedShader, StringView code)
	{
		Debug.Profiler.ProfileResourceFunction!();

		return ShaderCompiler.CompileAndReflectShader(code, importedShader.AssetIdentifier, vsName, "ps_5_0", .());
	}

	private static Result<void> ProcessFileContent(String fileContent, String outVsName, String outPsName,
		Dictionary<StringView, ShaderVariable> outVarDescs,
		List<String> outBufferNames, Dictionary<StringView, StringView> outEngineBuffers)
	{
		Debug.Profiler.ProfileResourceFunction!();

		Dictionary<StringView, StringView> arguments = scope .();

		int index = 0;

		while (true)
		{
			if ((int Start, int End) value = GetNextPreprocessor(fileContent, index, let name, arguments..Clear()))
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
							Log.EngineLogger.Error($"Unknown parameter name \"{name}\".");
							return .Err;
						}
					}
				case "EditorVariable":
					Try!(ProcessEditorVariables(arguments, outVarDescs));
				case "EngineBuffer":
					Try!(ProcessEngineBuffer(arguments, outBufferNames, outEngineBuffers));
				default:
					continue;
				}

				CommentLine(fileContent, value.Start);
			}
			else
			{
				break;
			}
		}

		return .Ok;
	}
	
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

	private static Result<void> ProcessEngineBuffer(Dictionary<StringView, StringView> arguments, 
		List<String> outBufferNames, Dictionary<StringView, StringView> outEngineBuffers)
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
				Log.EngineLogger.Error($"Unknown parameter for EngineBuffer: \"{argName}\".");
				delete nameInEngine;
				delete nameInShader;
				return .Err;
			}
		}

		if (String.IsNullOrWhiteSpace(nameInEngine) || String.IsNullOrWhiteSpace(nameInShader))
		{
			Log.EngineLogger.Error($"Name and Binding need to be defined.");
			delete nameInEngine;
			delete nameInShader;
			return .Err;
		}

		outBufferNames.Add(nameInShader);
		outBufferNames.Add(nameInEngine);
		outEngineBuffers.Add(nameInShader, nameInEngine);

		return .Ok;
	}

	private static Result<void> ProcessEditorVariables(Dictionary<StringView, StringView> arguments, Dictionary<StringView, ShaderVariable> outVarDescs)
	{
		ShaderVariable variable = new .();

		for (var (name, value) in arguments)
		{
			if (value.StartsWith('"') && value.EndsWith('"'))
			{
				value = value[1...^2];
			}

			switch(name)
			{
			case "Name":
				variable.Name = value;
			case "Min", "Max":
				if (Variant paramValue = ParseVariableValue(value))
					variable.AddParameter(name, paramValue);
				else
				{
					delete variable;
					return .Err;
				}
			default:
				Variant paramValue = Variant.Create(new String(value), true);
				variable.AddParameter(name, paramValue);
			}
		}

		if (variable.Name.IsWhiteSpace)
		{
			Log.EngineLogger.Error("Failed to process shader: Missing argument \"Name\" int variable description.");

			delete variable;

			return .Err;
		}

		outVarDescs.Add(variable.Name, variable);

		return .Ok;
	}

	private static Result<Variant> ParseVariableValue(StringView valueString)
	{
		if (valueString[0].IsDigit || valueString[0] == '-')
		{
			var valueString;

			if (valueString.EndsWith('f'))
				valueString.Length--;

			float value = Try!(float.Parse(valueString));

			return Variant.Create(value);
		}
		else if (valueString.StartsWith("float"))
		{
			int index = 5;

			int numComponents = valueString[index++] - '0';

			while (valueString[index] != '(')
			{
				if (!valueString[index].IsWhiteSpace)
				{
					Log.EngineLogger.Error("Failed to process shader: Expected '('.");
					return .Err;
				}

				index++;
			}

			if (numComponents < 2 || numComponents > 4)
			{
				Log.EngineLogger.Error($"Failed to process shader: Unsupported component count {numComponents}. Value must be between 2 and 4.");
				return .Err;
			}

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
			else
				return Variant.Create(*(float4*)floats.Ptr);
		}
		else
		{
			Log.EngineLogger.Error($"Failed to process shader: Unsupported variable value: \"{valueString}\".");
			return .Err;
		}
	}
}
