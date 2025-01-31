using System;
using System.Collections;
using GlitchyEngine.Content;
using GlitchyEngine.Renderer;
using Bon;
using GlitchyEngine.Math;
using System.IO;
using Bon.Integrated;
using GlitchyEngine;

namespace GlitchyEditor.Assets.Importers;

[BonTarget]
class MaterialVariable
{
	public ShaderVariableType ElementType;
	public int MatrixColumns;
	public int MatrixRows;
	public int ArrayElements;

	public uint8[] RawData ~ delete _;

	public this()
	{

	}

	public this(ShaderVariableType elementType, int matrixColumns, int matrixRows, int arrayElements)
	{
		ElementType = elementType;
		MatrixColumns = matrixColumns;
		MatrixRows = matrixRows;
		ArrayElements = arrayElements;

		RawData = new uint8[elementType.ElementSizeInBytes() * matrixColumns * matrixRows * arrayElements];
	}

	static this()
	{
		gBonEnv.typeHandlers.Add(typeof(Self),
			((.)new => VariableValueSerialize, (.)new => VariableValueDeserialize));
	}
	static void VariableValueSerialize(BonWriter writer, ValueView value, BonEnvironment env, SerializeValueState state)
	{
		/*Log.EngineLogger.Assert(value.type == typeof(Self));

		let variableValue = value.Get<Self>();

		writer.Type(variableValue)
		using (writer.ObjectBlock())
		{
			Serialize.Value(writer, nameof(MaterialFile.Effect), materialFile.Effect, env);
			Serialize.Value(writer, nameof(MaterialFile.Textures), materialFile.Textures, env);


		}*/
	}

	static Result<void> VariableValueDeserialize(BonReader reader, ValueView val, BonEnvironment env, DeserializeValueState state)
	{
		MaterialVariable output = val.Get<MaterialVariable>();

		StringView typeName = Try!(reader.EnumName());

		// If we don't find a digit, we assume entire type name is element type and rows string ends up being an empty string.
		int firstDigitIndex = typeName.Length;

		for (char8 c in typeName)
		{
			if (c.IsDigit)
			{
				firstDigitIndex = @c.Index;
			}
		}
		
		Result<ShaderVariableType> elementTypeResult = Enum.Parse<ShaderVariableType>(typeName.Substring(0, firstDigitIndex), true);

		if (elementTypeResult case .Err)
		{
			Deserialize.Error!("Unknown element type.", reader);
		}

		int xIndex = typeName.LastIndexOf('x');

		StringView rowsString = null;
		StringView columnsString = null;

		if (xIndex != -1)
		{
			rowsString = typeName.Substring(firstDigitIndex ..< xIndex);
			columnsString = typeName.Substring(xIndex + 1);
		}
		else
		{
			rowsString = typeName.Substring(firstDigitIndex);
		}

		Result<int, Int.ParseError> rowsResult = int.Parse(rowsString);

		if (rowsResult case .Err(let error))
		{
			switch (error)
			{
			case .NoValue:
				rowsResult = 1;
			case .Overflow:
				Deserialize.Error!("Integer overflow in row count.", reader);
			case .InvalidChar:
				Deserialize.Error!("Invalid character in row count.", reader);
			default:
				return .Err;
			}
		}
		
		Result<int, Int.ParseError> columnsResult = int.Parse(columnsString);

		if (columnsResult case .Err(let error))
		{
			switch (error)
			{
			case .NoValue:
				columnsResult = 1;
			case .Overflow:
				Deserialize.Error!("Integer overflow in column count.", reader);
			case .InvalidChar:
				Deserialize.Error!("Invalid character in column count.", reader);
			default:
				return .Err;
			}
		}

		// TODO: Array
		/*if (reader.[Friend]Check('['))
		{

		}*/

		output.ElementType = elementTypeResult.Get();
		output.MatrixRows = rowsResult.Get();
		output.MatrixColumns = columnsResult.Get();
		output.ArrayElements = 1;

		int elementSize = output.ElementType.ElementSizeInBytes();
		int elementCount = output.MatrixColumns * output.MatrixRows;

		output.RawData = new uint8[elementSize * elementCount * output.ArrayElements];

		Try!(reader.ObjectBlock());

		for (int currentElementIndex < elementCount)
		{
			switch (output.ElementType)
			{
			case .Float:
				StringView valueString = Try!(reader.Floating());

				float* rawFloats = (float*)output.RawData.Ptr;

				rawFloats[currentElementIndex] = Try!(float.Parse(valueString));
			case .Bool:
				// TODO: I'm pretty sure this is wrong, bools in c buffers are usually 32 bit
				bool value = Try!(reader.Bool());
				((bool*)&output.RawData)[currentElementIndex] = value;
			case .Int:
				StringView valueString = Try!(reader.Integer());
				((int32*)&output.RawData)[currentElementIndex] = Try!(int32.Parse(valueString));
			case .UInt:
				StringView valueString = Try!(reader.Integer());
				((uint32*)&output.RawData)[currentElementIndex] = Try!(uint32.Parse(valueString));
			}
		
			if (reader.ObjectHasMore())
			{
				Try!(reader.EntryEnd());
			}
			else
			{
				Log.EngineLogger.Warning("Vector/Matrix doesn't contain enough elements.");
				break;
			}
		}

		Try!(reader.ObjectBlockEnd());

		return .Ok;
	}
}

[BonTarget]
class NewMaterialFile : ImportedResource
{
	public AssetHandle<Effect> Effect;

	public Dictionary<String, AssetHandle<Texture>> Textures = new .() ~ DeleteDictionaryAndKeys!(_);
	public Dictionary<String, MaterialVariable> Constants = new .() ~ DeleteDictionaryAndKeysAndValues!(_);

	public this(AssetIdentifier ownAssetIdentifier) : base(ownAssetIdentifier)
	{

	}
}

class MaterialImporter: IAssetImporter
{
	private static readonly List<StringView> _fileExtensions = new .(){".mat"} ~ delete _;

	public static List<StringView> FileExtensions => _fileExtensions;
	
	public static Type ProcessedAssetType => typeof(NewMaterialFile);

	public AssetImporterConfig CreateDefaultConfig()
	{
		return new AssetImporterConfig();
	}

	public Result<ImportedResource> Import(StringView fullFileName, AssetIdentifier assetIdentifier, AssetConfig config)
	{
		NewMaterialFile material = new .(new AssetIdentifier(assetIdentifier.FullIdentifier));

		defer
		{
			if (@return case .Err)
			{
				delete material;
			}
		}

		String fullText = scope .();
		Try!(File.ReadAllText(fullFileName, fullText, true));

		Try!(Bon.Deserialize<NewMaterialFile>(ref material, fullText));

		return material;
	}

}