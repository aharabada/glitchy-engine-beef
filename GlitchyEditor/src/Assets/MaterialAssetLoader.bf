using Bon;
using GlitchyEngine.Content;
using System;
using System.Collections;
using System.IO;
using GlitchyEngine;
using GlitchyEngine.Renderer;
using ImGui;
using GlitchyEngine.Math;
using System.Diagnostics;
using Bon.Integrated;

namespace GlitchyEditor.Assets;

class MaterialAssetPropertiesEditor : AssetPropertiesEditor
{
	public static bool TryGetValue(Dictionary<String, Variant> parameters, String name, out Variant value)
	{
		if (parameters.TryGetValue(name, let param))
		{
			value = param;
			return true;
		}

		value = ?;

		return false;
	}

	mixin DropAssetTarget<T>() where T : Asset
	{
		AssetHandle handle = .Invalid;

		if (ImGui.BeginDragDropTarget())
		{
			ImGui.Payload* payload = ImGui.AcceptDragDropPayload("CONTENT_BROWSER_ITEM");
			
			if (payload != null)
			{
				StringView fullpath = .((char8*)payload.Data, (int)payload.DataSize);

				handle = Content.LoadAsset(fullpath);
			}

			ImGui.EndDragDropTarget();
		}

		handle
	}

	public this(AssetFile asset) : base(asset)
	{

	}

	public override void ShowEditor()
	{
		Material material = Asset.LoadedAsset as Material;

		if (material == null)
			return;
		
		Effect effect = material?.Effect;

		if (effect == null)
			return;

		ShowTextures(material, effect);

		ShowVariables(material, effect);
	}

	private void ShowTextures(Material material, Effect effect)
	{
		for (let texture in effect.Textures)
		{
			ImGui.Button(texture.key);

			if (ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = ImGui.AcceptDragDropPayload("CONTENT_BROWSER_ITEM");

				if (payload != null)
				{
					StringView path = .((char8*)payload.Data, (int)payload.DataSize);

					AssetHandle<Texture2D> newTexture = Content.LoadAsset(path);

					//newTexture.Get().SamplerState = SamplerStateManager.AnisotropicWrap;
					material.SetTexture(texture.key, newTexture.Cast<Texture>());
				}

				ImGui.EndDragDropTarget();
			}
		}
	}

	private void ShowVariables(Material material, Effect effect)
	{
		for (let (name, arguments) in effect.[Friend]_variableDescriptions)
		{
			if (!effect.Variables.TryGetVariable(name, let variable))
				continue;
			
			bool hasPreviewName = TryGetValue(arguments, "Preview", var previewName);

			StringView displayName = hasPreviewName ? previewName.Get<String>() : name;
			
			bool hasPreviewType = TryGetValue(arguments, "Type", var previewType);

			if (hasPreviewType && (previewType.Get<String>() == "Color" || previewType.Get<String>() == "ColorHDR"))
			{
				if (previewType.Get<String>().Equals("Color", .InvariantCultureIgnoreCase))
				{
					Log.EngineLogger.AssertDebug(variable.Type == .Float && variable.Rows == 1);

					if (variable.Columns == 3)
					{
						material.GetVariable<float3>(variable.Name, var value);

						value = (float3)ColorRGB.LinearToSRGB((ColorRGB)value);

						if (ImGui.ColorEdit3(displayName.Ptr, *(float[3]*)&value))
						{
							value = (float3)ColorRGB.SRgbToLinear((ColorRGB)value);
							material.SetVariable(variable.Name, value);
						}
					}
					else if (variable.Columns == 4)
					{
						material.GetVariable<float4>(variable.Name, var value);
						
						value = (float4)ColorRGBA.LinearToSRGB((ColorRGBA)value);

						if (ImGui.ColorEdit4(displayName.Ptr, *(float[4]*)&value))
						{
							value = (float4)ColorRGBA.SRgbToLinear((ColorRGBA)value);
							material.SetVariable(variable.Name, value);
						}
					}
				}
				else if (previewType.Get<String>().Equals("ColorHDR", .InvariantCultureIgnoreCase))
				{
					Log.EngineLogger.AssertDebug(variable.Type == .Float && variable.Rows == 1);

					if (variable.Columns == 3)
					{
						material.GetVariable<float3>(variable.Name, var value);

						value = (float3)ColorRGB.LinearToSRGB((ColorRGB)value);

						if (ImGui.ColorEdit3(displayName.Ptr, *(float[3]*)&value, .HDR | .Float))
						{
							value = (float3)ColorRGB.SRgbToLinear((ColorRGB)value);
							material.SetVariable(variable.Name, value);
						}
					}
					else if (variable.Columns == 4)
					{
						material.GetVariable<float4>(variable.Name, var value);
						
						value = (float4)ColorRGBA.LinearToSRGB((ColorRGBA)value);

						if (ImGui.ColorEdit4(displayName.Ptr, *(float[4]*)&value, .HDR | .Float))
						{
							value = (float4)ColorRGBA.SRgbToLinear((ColorRGBA)value);
							material.SetVariable(variable.Name, value);
						}
					}
				}
			}
			//ImGui.ColorEdit3("", null, .HDR | .Float)

			else if (variable.Type == .Float && variable.Rows == 1)
			{
				bool hasMin = TryGetValue(arguments, "Min", var min);
				bool hasMax = TryGetValue(arguments, "Max", var max);

				for (int r < variable.Rows)
				{
					switch (variable.Columns)
					{
					case 1:
						material.GetVariable<float>(variable.Name, var value);
						
						float[1] minV = hasMin ? min.Get<float[1]>() : .(float.MinValue);
						float[1] maxV = hasMax ? max.Get<float[1]>() : .(float.MaxValue);

						if (ImGui.EditVector<1>(displayName, ref *(float[1]*)&value, .(), 0.1f, 100.0f, minV, maxV))
							material.SetVariable(variable.Name, value);
					case 2:
						material.GetVariable<float2>(variable.Name, var value);
						
						float2 minV = hasMin ? min.Get<float2>() : (float2)float.MinValue;
						float2 maxV = hasMax ? max.Get<float2>() : (float2)float.MaxValue;
						
						if (ImGui.Editfloat2(displayName, ref value, .Zero, 0.1f, 100.0f, minV, maxV))
							material.SetVariable(variable.Name, value);
					case 3:
						material.GetVariable<float3>(variable.Name, var value);
						
						float3 minV = hasMin ? min.Get<float3>() : (float3)float.MinValue;
						float3 maxV = hasMax ? max.Get<float3>() : (float3)float.MaxValue;

						if (ImGui.Editfloat3(displayName, ref value, .Zero, 0.1f, 100.0f, minV, maxV))
							material.SetVariable(variable.Name, value);
					case 4:
						material.GetVariable<float4>(variable.Name, var value);
						
						float4 minV = hasMin ? min.Get<float4>() : (float4)float.MinValue;
						float4 maxV = hasMax ? max.Get<float4>() : (float4)float.MaxValue;

						if (ImGui.Editfloat4(displayName, ref value, .Zero, 0.1f, 100.0f, minV, maxV))
							material.SetVariable(variable.Name, value);
					}
				}
			}
		}
	}

	public static AssetPropertiesEditor Factory(AssetFile assetFile)
	{
		return new Self(assetFile);
	}
}

[BonTarget, BonPolyRegister]
class MaterialAssetLoaderConfig : AssetLoaderConfig
{
	
}

[BonTarget]
public enum VariableValue
{
	case Float(float Value);
	case Float2(float2 Value);
	case Float3(float3 Value);
	case Float4(float4 Value);
	case Int(int Value);
	case Int2(Int2 Value);
	case Int3(Int3 Value);
	case Int4(Int4 Value);
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

[BonTarget]
class MaterialFile
{
	public String Effect ~ delete _;

	public Dictionary<String, String> Textures ~ DeleteDictionaryAndKeysAndValues!(_);
	public Dictionary<String, VariableValue> Variables ~
		{
			if (_ != null)
			{
				for (var entry in _)
				{
					delete entry.key;
					//delete entry.value;
					/*if (entry.value.HasValue)
						entry.value->Dispose();*/
				}
	
				delete _;
			}
		};

	/*static this()
	{
		gBonEnv.typeHandlers.Add(typeof(Self),
			((.)new => MaterialSerialize, (.)new => MaterialDeserialize));
	}

	static void MaterialSerialize(BonWriter writer, ValueView value, BonEnvironment env)
	{
		Log.EngineLogger.Assert(value.type == typeof(Self));

		let materialFile = value.Get<Self>();

		using (writer.ObjectBlock())
		{
			Serialize.Value(writer, nameof(MaterialFile.Effect), materialFile.Effect, env);
			Serialize.Value(writer, nameof(MaterialFile.Textures), materialFile.Textures, env);


		}
	}

	private static void SerializeVariablesDictionary(BonWriter writer, MaterialFile materialFile, BonEnvironment env)
	{
		using (writer.ArrayBlock())
		{
			for (let (name, value) in materialFile.Variables)
			{
				let keyVal = ValueView(typeof(String), name);
				Serialize.Value(writer, keyVal, env);
				writer.Pair();

				ValueView valueVal;// = ValueView(, entriesPtr + (currentIndex * entryStride) + entryValueOffset);
				switch(value.GetType())
				{
				case typeof(ColorRGBA):
					writer.Identifier("ColorRGBA");
				default:

				}

				Serialize.Value(writer, valueVal, env);
			}
		}
	}

	static Result<void> MaterialDeserialize(BonReader reader, ValueView val, BonEnvironment env)
	{
		return .Ok;
	}*/
}

class MaterialAssetLoader : IAssetLoader, IAssetSaver //, IReloadingAssetLoader
{
	private static readonly List<StringView> _fileExtensions = new .(){".mat"} ~ delete _;

	public static List<StringView> FileExtensions => _fileExtensions;

	public AssetLoaderConfig GetDefaultConfig()
	{
		return new ModelAssetLoaderConfig();
	}

	public Asset LoadAsset(Stream file, AssetLoaderConfig config, StringView assetIdentifier, StringView? subAsset, IContentManager contentManager)
	{
		StreamReader reader = scope .(file);

		String text = scope .();

		reader.ReadToEnd(text);

		MaterialFile materialFile = scope .();

		var result = Bon.Deserialize<MaterialFile>(ref materialFile, text);
		
		if (result case .Err)
		{
			Log.EngineLogger.Error("Failed to load material.");
			Debug.SafeBreak();
			return null;
		}

		Effect fx = Content.GetAsset<Effect>(contentManager.LoadAsset(materialFile.Effect, true), contentManager);

		Material material = new Material(fx);

		for (let (slotName, textureIdentifier) in materialFile.Textures)
		{

			AssetHandle<Texture> texture = contentManager.LoadAsset(textureIdentifier);

			if (texture.IsInvalid)
			{
				Log.EngineLogger.Error($"Failed to load texture \"{textureIdentifier}\".");
			}

			material.SetTexture(slotName, texture);
		}

		for (let (slotName, variableValue) in materialFile.Variables)
		{
			switch (variableValue)
			{
			case .ColorRGBA(let value):
				material.SetVariable(slotName, value);
			case .ColorRGB(let value):
				material.SetVariable(slotName, value);
			case .Float(let value):
				material.SetVariable(slotName, value);
			case .Float2(let value):
				material.SetVariable(slotName, value);
			case .Float3(let value):
				material.SetVariable(slotName, value);
			case .Float4(let value):
				material.SetVariable(slotName, value);
			case .None:
			default:
				Log.EngineLogger.Error($"Unknown variable type of variable {slotName}: {variableValue}");
			}

			
		}

		return material;
	}

	public Result<void> EditorSaveAsset(Stream file, Asset asset, AssetLoaderConfig config, StringView assetIdentifier, StringView? subAsset, IContentManager contentManager)
	{
		Material material = asset as Material;

		if (material == null)
		{
			Log.EngineLogger.Error("Asset must be a Material!");
			return .Err;
		}

		MaterialFile materialFile = scope .();

		materialFile.Effect = new String(material.Effect.Identifier);
		materialFile.Textures = new .();
		materialFile.Variables = new .();

		for (let (slotName, texture) in material.[Friend]_textures)
		{
			Texture textureAsset = texture.Handle.Get();

			materialFile.Textures.Add(new String(slotName), new String(textureAsset?.Identifier ?? ""));
		}

		Effect effect = material.Effect;

		if (effect == null)
			return .Ok;

		for (let (name, arguments) in effect.[Friend]_variableDescriptions)
		{
			VariableValue variableValue = .None;

			let variable = effect.Variables[name];
			
			bool hasPreviewType = MaterialAssetPropertiesEditor.TryGetValue(arguments, "Type", var previewType);

			if (hasPreviewType && previewType.Get<String>() == "Color")
			{
				Log.EngineLogger.AssertDebug(variable.Type == .Float && variable.Rows == 1);

				if (variable.Columns == 3)
				{
					material.GetVariable<ColorRGB>(variable.Name, var value);

					value = ColorRGB.LinearToSRGB((ColorRGB)value);

					//variantValue = new box value;
					variableValue = .ColorRGB(value);
				}
				else if (variable.Columns == 4)
				{
					material.GetVariable<ColorRGBA>(variable.Name, var value);
					
					value = ColorRGBA.LinearToSRGB((ColorRGBA)value);
					
					variableValue = .ColorRGBA(value);
				}
			}
			else if (variable.Type == .Float && variable.Rows == 1)
			{
				switch (variable.Columns)
				{
				case 1:
					material.GetVariable<float>(variable.Name, let value);
					variableValue = .Float(value);
				case 2:
					material.GetVariable<float2>(variable.Name, let value);
					variableValue = .Float2(value);
				case 3:
					material.GetVariable<float3>(variable.Name, let value);
					variableValue = .Float3(value);
				case 4:
					material.GetVariable<float4>(variable.Name, let value);
					variableValue = .Float4(value);
				}
			}

			materialFile.Variables.Add(new String(name), variableValue);
		}

		String text = scope .();
		
		gBonEnv.serializeFlags |= .IncludeDefault | .Verbose;

		Bon.Serialize<MaterialFile>(materialFile, text);

		StreamWriter writer = scope .(file, .UTF8, 1024);
		writer.Write(text);

		return .Ok;
	}

	Material _placeholder;
	Material _error;

	public Asset GetPlaceholderAsset(Type assetType)
	{
		return default;
	}

	public Asset GetErrorAsset(Type assetType)
	{
		return default;
	}
}