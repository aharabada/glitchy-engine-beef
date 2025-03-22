using System;
using System.Collections;
using GlitchyEngine;
using GlitchyEngine.Math;

namespace GlitchyEditor.Assets.Processors;

static class ShaderCodePreprocessor
{
	public static Result<void> ProcessFileContent(String fileContent, String outVsName, String outPsName,
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
		var startindex;

		name = .();

		int startOfLine = -1;
		int startOfPragma = -1;
		int endOfLine = startindex;
		do
		{
			repeat
			{
				startindex = endOfLine;

				startOfPragma = code.IndexOf("#pragma", startindex);

				if (startOfPragma == -1)
					return .Err;
				
				endOfLine = code.IndexOf('\n', startOfPragma);

				startOfLine = code[...startOfPragma].LastIndexOf('\n');
				
				// If the line is commented out, look for the next
			} while (startOfLine != -1 && code[startOfLine...startOfPragma].Contains("//"));

			StringView line = (endOfLine != -1) ? code.Substring(startOfPragma, endOfLine - startOfPragma) : code.Substring(startOfPragma);

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

		return .Ok((startOfPragma, endOfLine));
	}

	private static Result<void> ProcessEngineBuffer(Dictionary<StringView, StringView> arguments, 
		List<String> outBufferNames, Dictionary<StringView, StringView> outEngineBuffers)
	{
		String nameInEngine = null;
		String nameInShader = null;
		
		defer
		{
			if (@return case .Err)
			{
				delete nameInEngine;
				delete nameInShader;
			}
		}

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
				return .Err;
			}
		}

		if (String.IsNullOrWhiteSpace(nameInEngine) || String.IsNullOrWhiteSpace(nameInShader))
		{
			Log.EngineLogger.Error($"Name and Binding need to be defined.");
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

		defer
		{
			if (@return case .Err)
				delete variable;
		}

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
			case "Preview":
				variable.PreviewName = value;
			case "Type":
				variable.EditorType = value;
			case "Min":
				variable.MinValue = Try!(ParseVariableValue(value));
			case "Max":
				variable.MaxValue = Try!(ParseVariableValue(value));
			default:
				Variant paramValue = Variant.Create(new String(value), true);
				variable.AddParameter(name, paramValue);
			}
		}

		if (variable.Name.IsWhiteSpace)
		{
			Log.EngineLogger.Error("Failed to process shader: Missing argument \"Name\" int variable description.");
			return .Err;
		}

		outVarDescs.Add(variable.Name, variable);

		return .Ok;
	}

	private static Result<Variant> ParseVariableValue(StringView valueString)
	{
		// TODO: Simply always use double?

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