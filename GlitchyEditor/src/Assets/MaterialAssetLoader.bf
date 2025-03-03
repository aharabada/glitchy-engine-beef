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
			ImGui.Payload* payload = ImGui.AcceptDragDropPayload(.ContentBrowserItem);
			
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

		ImGui.TextUnformatted("Effect: ");
		ImGui.SameLine();
		
		Effect effect = material?.Effect;

		StringView effectName = (effect?.Identifier ?? "(None)");

		ImGui.Button(effectName.ToScopeCStr!());

		ImGui.AttachTooltip(effectName);

		// Effect drop target
		if (ImGui.BeginDragDropTarget())
		{
			ImGui.Payload* payload = ImGui.AcceptDragDropPayload(.ContentBrowserItem);

			if (payload != null)
			{
				StringView path = .((char8*)payload.Data, (int)payload.DataSize);

				AssetHandle<Effect> newEffect = Content.LoadAsset(path);

				material.Effect = newEffect;

				//newTexture.Get().SamplerState = SamplerStateManager.AnisotropicWrap;
				//material.SetTexture(texture.key, newTexture.Cast<Texture>());
			}

			ImGui.EndDragDropTarget();
		}

		if (effect == null)
			return;

		ShowTextures(material, effect);

		ShowVariables(material, effect);
	}

	private void ShowTextures(Material material, Effect effect)
	{
		for (let texture in effect.Textures)
		{
			ImGui.TextUnformatted(texture.key);
			ImGui.SameLine();

			ImGui.Button("Texture");

			if (ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = ImGui.AcceptDragDropPayload(.ContentBrowserItem);

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
					Log.EngineLogger.AssertDebug(variable.ElementType == .Float && variable.Rows == 1);

					if (variable.Columns == 3)
					{
						material.GetVariable<float3>(variable.Name, var value);

						value = (float3)ColorRGB.LinearToSRGB((ColorRGB)value);

						if (ImGui.ColorEdit3(displayName.Ptr, ref *(float[3]*)&value))
						{
							value = (float3)ColorRGB.SRgbToLinear((ColorRGB)value);
							material.SetVariable(variable.Name, value);
						}
					}
					else if (variable.Columns == 4)
					{
						material.GetVariable<float4>(variable.Name, var value);
						
						value = (float4)ColorRGBA.LinearToSRGB((ColorRGBA)value);

						if (ImGui.ColorEdit4(displayName.Ptr, ref *(float[4]*)&value))
						{
							value = (float4)ColorRGBA.SRgbToLinear((ColorRGBA)value);
							material.SetVariable(variable.Name, value);
						}
					}
				}
				else if (previewType.Get<String>().Equals("ColorHDR", .InvariantCultureIgnoreCase))
				{
					Log.EngineLogger.AssertDebug(variable.ElementType == .Float && variable.Rows == 1);

					if (variable.Columns == 3)
					{
						material.GetVariable<float3>(variable.Name, var value);

						value = (float3)ColorRGB.LinearToSRGB((ColorRGB)value);

						if (ImGui.ColorEdit3(displayName.Ptr, ref *(float[3]*)&value, .HDR | .Float))
						{
							value = (float3)ColorRGB.SRgbToLinear((ColorRGB)value);
							material.SetVariable(variable.Name, value);
						}
					}
					else if (variable.Columns == 4)
					{
						material.GetVariable<float4>(variable.Name, var value);
						
						value = (float4)ColorRGBA.LinearToSRGB((ColorRGBA)value);

						if (ImGui.ColorEdit4(displayName.Ptr, ref *(float[4]*)&value, .HDR | .Float))
						{
							value = (float4)ColorRGBA.SRgbToLinear((ColorRGBA)value);
							material.SetVariable(variable.Name, value);
						}
					}
				}
			}
			//ImGui.ColorEdit3("", null, .HDR | .Float)

			else if (variable.ElementType == .Float && variable.Rows == 1)
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
						
						if (ImGui.EditFloat2(displayName, ref value, .Zero, 0.1f, 100.0f, minV, maxV))
							material.SetVariable(variable.Name, value);
					case 3:
						material.GetVariable<float3>(variable.Name, var value);
						
						float3 minV = hasMin ? min.Get<float3>() : (float3)float.MinValue;
						float3 maxV = hasMax ? max.Get<float3>() : (float3)float.MaxValue;

						if (ImGui.EditFloat3(displayName, ref value, .Zero, 0.1f, 100.0f, minV, maxV))
							material.SetVariable(variable.Name, value);
					case 4:
						material.GetVariable<float4>(variable.Name, var value);
						
						float4 minV = hasMin ? min.Get<float4>() : (float4)float.MinValue;
						float4 maxV = hasMax ? max.Get<float4>() : (float4)float.MaxValue;

						if (ImGui.EditFloat4(displayName, ref value, .Zero, 0.1f, 100.0f, minV, maxV))
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
