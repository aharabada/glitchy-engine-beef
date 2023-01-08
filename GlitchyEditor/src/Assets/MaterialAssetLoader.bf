using Bon;
using GlitchyEngine.Content;
using System;
using System.Collections;
using System.IO;
using GlitchyEngine;
using GlitchyEngine.Renderer;
using ImGui;
using GlitchyEngine.Math;

namespace GlitchyEditor.Assets;

class MaterialAssetPropertiesEditor : AssetPropertiesEditor
{
	mixin DropAssetTarget<T>() where T : Asset
	{
		Asset asset = null;

		if (ImGui.BeginDragDropTarget())
		{
			ImGui.Payload* payload = ImGui.AcceptDragDropPayload("CONTENT_BROWSER_ITEM");
			
			if (payload != null)
			{
				StringView fullpath = .((char8*)payload.Data, (int)payload.DataSize);

				asset = Content.LoadAsset<Asset>(fullpath);
			}

			ImGui.EndDragDropTarget();
		}

		asset
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

					using (Texture2D newTexture = Content.LoadAsset<Texture2D>(path))//new Texture2D(path, true))
					{
						newTexture.SamplerState = SamplerStateManager.AnisotropicWrap;
						material.SetTexture(texture.key, newTexture);
					}
				}

				ImGui.EndDragDropTarget();
			}
		}
	}

	private void ShowVariables(Material material, Effect effect)
	{
		bool TryGetValue(Dictionary<String, Variant> parameters, String name, out Variant value)
		{
			if (parameters.TryGetValue(name, let param))
			{
				value = param;
				return true;
			}

			value = ?;

			return false;
		}

		for (let (name, arguments) in effect.[Friend]_variableDescriptions)
		{
			let variable = effect.Variables[name];
			
			bool hasPreviewName = TryGetValue(arguments, "Preview", var previewName);

			StringView displayName = hasPreviewName ? previewName.Get<String>() : name;
			
			bool hasPreviewType = TryGetValue(arguments, "Type", var previewType);

			if (hasPreviewType && previewType.Get<String>() == "Color")
			{
				Log.EngineLogger.AssertDebug(variable.Type == .Float && variable.Rows == 1);

				if (variable.Columns == 3)
				{
					material.GetVariable<Vector3>(variable.Name, var value);

					value = (Vector3)ColorRGB.LinearToSRGB((ColorRGB)value);

					if (ImGui.ColorEdit3(displayName.Ptr, *(float[3]*)&value))
					{
						value = (Vector3)ColorRGB.SRgbToLinear((ColorRGB)value);
						material.SetVariable(variable.Name, value);
					}
				}
				else if (variable.Columns == 4)
				{
					material.GetVariable<Vector4>(variable.Name, var value);
					
					value = (Vector4)ColorRGBA.LinearToSRGB((ColorRGBA)value);

					if (ImGui.ColorEdit4(displayName.Ptr, *(float[4]*)&value))
					{
						value = (Vector4)ColorRGBA.SRgbToLinear((ColorRGBA)value);
						material.SetVariable(variable.Name, value);
					}
				}
			}
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
						material.GetVariable<Vector2>(variable.Name, var value);
						
						Vector2 minV = hasMin ? min.Get<Vector2>() : .(float.MinValue);
						Vector2 maxV = hasMax ? max.Get<Vector2>() : .(float.MaxValue);
						
						if (ImGui.EditVector2(displayName, ref value, .Zero, 0.1f, 100.0f, minV, maxV))
							material.SetVariable(variable.Name, value);
					case 3:
						material.GetVariable<Vector3>(variable.Name, var value);
						
						Vector3 minV = hasMin ? min.Get<Vector3>() : .(float.MinValue);
						Vector3 maxV = hasMax ? max.Get<Vector3>() : .(float.MaxValue);

						if (ImGui.EditVector3(displayName, ref value, .Zero, 0.1f, 100.0f, minV, maxV))
							material.SetVariable(variable.Name, value);
					case 4:
						material.GetVariable<Vector4>(variable.Name, var value);
						
						Vector4 minV = hasMin ? min.Get<Vector4>() : .(float.MinValue);
						Vector4 maxV = hasMax ? max.Get<Vector4>() : .(float.MaxValue);

						if (ImGui.EditVector4(displayName, ref value, .Zero, 0.1f, 100.0f, minV, maxV))
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
class MaterialFile
{
	public String Effect ~ delete _;

	public Dictionary<String, String> Textures ~ DeleteDictionaryAndKeysAndValues!(_);
	//public Dictionary<String, Object> Variables;
}

class MaterialAssetLoader : IAssetLoader //, IReloadingAssetLoader
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
			return null;
			// TODO: return error material
		}

		Effect fx = new Effect(materialFile.Effect);

		Material material = new Material(fx);

		for (let (slotName, textureIdentifier) in materialFile.Textures)
		{
			using (Texture texture = contentManager.LoadAsset(textureIdentifier) as Texture)
			{
				if (texture == null)
				{
					Log.EngineLogger.Error("Failed to load texture.");
					// TODO: LoadAsset should return an error texture.
				}

				material.SetTexture(slotName, texture);
			}
		}

		fx.ReleaseRef();

		/*for (let (slotName, textureIdentifier) in materialFile.Variables)
		{
			if (texture == null)
			{
				Log.EngineLogger.Error("Failed to load texture.");
				// TODO: LoadAsset should return an error texture.
			}

			material.SetVariable(slotName, );
		}*/

		return material; //ModelLoader.LoadMesh(file, subAsset.Value, 0);
	}
}