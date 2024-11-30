using System;
using System.Collections;
using GlitchyEngine.Content;
using GlitchyEngine.Renderer;
using Bon;
using GlitchyEngine.Math;
using System.IO;

namespace GlitchyEditor.Assets.Importers;

[BonTarget]
class NewMaterialFile : ImportedResource
{
	public AssetHandle<Effect> Effect;

	public Dictionary<String, AssetHandle<Texture>> Textures = new .() ~ DeleteDictionaryAndKeys!(_);
	public Dictionary<String, MaterialVariableValue> Constants = new .() ~ DeleteDictionaryAndKeys!(_);

	public this(AssetIdentifier ownAssetIdentifier) : base(ownAssetIdentifier)
	{

	}
}


[BonTarget]
public enum MaterialVariableValue
{
	case bool(bool Value);
	case bool2(bool2 Value);
	case bool3(bool3 Value);
	case bool4(bool4 Value);
	case int(int Value);
	case int2(int2 Value);
	case int3(int3 Value);
	case int4(int4 Value);
	case uint(uint Value);
	case uint2(uint2 Value);
	case uint3(uint3 Value);
	case uint4(uint4 Value);
	case Float(float Value);
	case Float2(float2 Value);
	case Float3(float3 Value);
	case Float4(float4 Value);
	case Half(half Value);
	case Half2(half2 Value);
	case Half3(half3 Value);
	case Half4(half4 Value);
	case ColorRGB(ColorRGB Value);
	case ColorRGBA(ColorRGBA Value);
	case None;

	/*static this()
	{
		gBonEnv.typeHandlers.Add(typeof(Self),
			((.)new => VariableValueSerialize, (.)new => VariableValueDeserialize));
	}

	static void VariableValueSerialize(BonWriter writer, ValueView value, BonEnvironment env)
	{
		Log.EngineLogger.Assert(value.type == typeof(Self));

		let variableValue = value.Get<Self>();

		writer.Type(variableValue)
		using (writer.ObjectBlock())
		{
			Serialize.Value(writer, nameof(MaterialFile.Effect), materialFile.Effect, env);
			Serialize.Value(writer, nameof(MaterialFile.Textures), materialFile.Textures, env);


		}
	}
	
	static Result<void> VariableValueDeserialize(BonReader reader, ValueView val, BonEnvironment env)
	{
		return .Ok;
	}*/
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