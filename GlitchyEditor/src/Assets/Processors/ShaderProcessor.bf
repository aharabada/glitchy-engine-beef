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
	public override AssetType AssetType => .Shader;

	public CompiledShader VertexShader ~ delete _;
	public CompiledShader PixelShader ~ delete _;

	public this(AssetIdentifier ownAssetIdentifier, AssetHandle assetHandle) : base(ownAssetIdentifier, assetHandle)
	{

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
		Dictionary<String, String> engineBuffers = scope .();

		defer
		{
			ClearDictionaryAndDeleteValues!(variables);

			for (let (key, value) in engineBuffers)
			{
				delete key;
				delete value;
			}
		}

		String code = new String(importedShader.HlslCode);
		defer { delete code; }

		Try!(ProcessFileContent(code, vsName, psName, variables, engineBuffers));

		if (String.IsNullOrWhiteSpace(vsName) && String.IsNullOrWhiteSpace(psName))
		{
			// this is not an effect -> we don't need to compile it
			return .Ok;
		}

		ProcessedShader processedShader = new ProcessedShader(new AssetIdentifier(importedShader.AssetIdentifier), config.AssetHandle);

		Try!(CompileAndReflect(vsName, psName, importedShader, code, processedShader));

		Try!(MergeResources(processedShader));

		outProcessedResources.Add(processedShader);

		return .Ok;
	}

	private static Result<void> MergeResources(ProcessedShader processedShader)
	{


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

	private static Result<void> ProcessFileContent(String fileContent, String outVsName, String outPsName, Dictionary<StringView, ShaderVariable> outVarDescs, Dictionary<String, String> outEngineBuffers)
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
					Try!(ProcessEngineBuffer(arguments, outEngineBuffers));
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

	private static Result<void> ProcessEngineBuffer(Dictionary<StringView, StringView> arguments, Dictionary<String, String> outEngineBuffers)
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

		outEngineBuffers.Add(nameInEngine, nameInShader);

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
