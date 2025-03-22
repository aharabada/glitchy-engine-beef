using GlitchyEngine.Renderer;
using ImGui;
using System;
using GlitchyEngine.Math;
using GlitchyEditor.EditWindows;
using GlitchyEngine.Content;

namespace GlitchyEditor.Assets.Editors;

class MaterialEditor
{
	public static bool ShowEditor(AssetFile assetFile)
	{
		bool isDirty = false;

		let material = assetFile.LoadedAsset as Material;

		if (material == null)
			return isDirty;

		ImGui.PropertyTableStartNewProperty("Base Material");

		if (material.Parent != null)
			ImGui.TextUnformatted(material.Parent.Identifier);
		else
			ImGui.TextUnformatted("None");

		ImGui.PropertyTableStartNewProperty("Shader");

		ImGui.TextUnformatted(material.Effect.Identifier);
		
		ImGui.PropertyTableStartNewRow();
		if (ImGui.CollapsingHeader("Parameters", .DefaultOpen | .AllowOverlap | .Framed | .SpanFullWidth | .SpanAllColumns))
		{
			String prettyVariableName = scope .();
			for (let (variableName, bufferVariable) in material.Variables)
			{
				// Don't show engine buffer variables
				if (!bufferVariable.ConstantBuffer.EngineBufferName.IsEmpty)
				{
					continue;
				}

				ImGui.PushID(variableName);

				ImGui.PropertyTableStartNewRow();

				bool readOnly = bufferVariable.Flags.HasFlag(.Readonly);

				ImGui.BeginDisabled(readOnly);

				if (DrawLockButton(bufferVariable.Flags.HasFlag(.Locked)) && !readOnly)
				{
					bufferVariable.[Friend]_flags ^= .Locked;
				}

				ImGui.SameLine();

				StringView displayName = bufferVariable.PreviewName;

				if (displayName.IsEmpty)
				{
					ToPrettyName(variableName, prettyVariableName);
					displayName = prettyVariableName;
				}

				ImGui.PropertyTableName(displayName);

				// TODO: Somehow pass display name and type from imported shader to here!

				bool handled = false;

				switch (bufferVariable.EditorTypeName)
				{
				case "Color", "ColorHDR":
					if (bufferVariable.ElementType != .Float || bufferVariable.Rows != 1 ||
						bufferVariable.Columns < 3)
					{
						break;
					}

					ImGui.ColorEditFlags flags = .None;

					if (_ == "ColorHDR")
					{
						flags |= .HDR | .Float;
					}

					if (bufferVariable.Columns == 3)
					{
						material.GetVariable<float3>(bufferVariable.Name, var value);
						if (ImGui.ColorEdit3("", ref *(float[3]*)&value, flags))
							material.SetVariable(bufferVariable.Name, value);
					}
					else if (bufferVariable.Columns == 4)
					{
						material.GetVariable<float4>(bufferVariable.Name, var value);
						if (ImGui.ColorEdit4("", ref *(float[4]*)&value, flags))
							material.SetVariable(bufferVariable.Name, value);
					}

					handled = true;
				}

				if (!handled)
				{
					switch (bufferVariable.ElementType)
					{
					case .Float:
						// TODO: min and max values specified in shader
						// TODO: support drag and enter number (specified in shader)

						//for (int r < bufferVariable.Rows)
						if (bufferVariable.Rows == 1)
						{
							switch (bufferVariable.Columns)
							{
							case 1:
								material.GetVariable<float>(bufferVariable.Name, var value);
								
								//float[1] minV = hasMin ? min.Get<float[1]>() : .(float.MinValue);
								//float[1] maxV = hasMax ? max.Get<float[1]>() : .(float.MaxValue);

								if (ImGui.VectorEditor<1>("", ref *(float[1]*)&value, .(), 0.1f /*, minV, maxV*/))
									material.SetVariable(bufferVariable.Name, value);
							case 2:
								material.GetVariable<float2>(bufferVariable.Name, var value);
								if (ImGui.Float2Editor("", ref value, .Zero, 0.1f, 100.0f))
									material.SetVariable(bufferVariable.Name, value);
							case 3:
								material.GetVariable<float3>(bufferVariable.Name, var value);
								if (ImGui.Float3Editor("", ref value, .Zero, 0.1f, 100.0f))
									material.SetVariable(bufferVariable.Name, value);
							case 4:
								material.GetVariable<float4>(bufferVariable.Name, var value);
								if (ImGui.Float4Editor("", ref value, .Zero, 0.1f, 100.0f))
									material.SetVariable(bufferVariable.Name, value);
							}
						}
					default:
						ImGui.TextUnformatted(scope $"Element Type {_} not supported");
					}
				}

				ImGui.EndDisabled();

				ImGui.PopID();
			}
		}
		
		ImGui.PropertyTableStartNewRow();
		if (ImGui.CollapsingHeader("Textures", .DefaultOpen | .AllowOverlap | .Framed | .SpanFullWidth | .SpanAllColumns))
		{
			String prettyVariableName = scope .();
			for (var (textureName, texture) in ref material.Textures)
			{
				ImGui.PushID(textureName);

				ImGui.PropertyTableStartNewRow();
				
				bool readOnly = texture.Flags.HasFlag(.Readonly);

				ImGui.BeginDisabled(readOnly);

				if (DrawLockButton(texture.Flags.HasFlag(.Locked)) && !readOnly)
				{
					texture.Flags ^= .Locked;
				}

				ImGui.SameLine();

				// TODO: Preview Name for textures
				StringView displayName = "";//texture.PreviewName;

				if (displayName.IsEmpty)
				{
					ToPrettyName(textureName, prettyVariableName);
					displayName = prettyVariableName;
				}


				ImGui.PropertyTableName(displayName);

				if (ComponentEditWindow.ShowAssetDropTarget<Texture>(ref texture.TextureHandle))
				{

				}

				ImGui.EndDisabled();

				ImGui.PopID();
			}
		}

		return isDirty;
	}

	private static bool DrawLockButton(bool isLocked)
	{
		ImGui.PushStyleVar(.ItemInnerSpacing, ImGui.Vec2(0, 0));
		ImGui.PushStyleColor(.Button, ImGui.Vec4(0, 0, 0, 0));

		let colors = ImGui.GetStyle().Colors;

		ImGui.Vec4 hoveredColor = colors[(int)ImGui.Col.ButtonHovered];
		hoveredColor.w = 0.5f;

		ImGui.Vec4 activeColor = colors[(int)ImGui.Col.ButtonActive];
		activeColor.w = 0.5f;

		ImGui.PushStyleColor(.ButtonHovered, hoveredColor);
		ImGui.PushStyleColor(.ButtonActive, activeColor);

		float padding = 2.0f;

		float size = ImGui.GetTextLineHeight() - 2 * padding;

		ImGui.PushID(0);

		bool result = ImGui.ImageButton("", isLocked ? EditorIcons.Instance.Icon_Locked : EditorIcons.Instance.Icon_Unlocked, .(size, size), .Zero, .Ones);
		
		ImGui.PopID();

		if (isLocked)
			ImGui.AttachTooltip("Click to unlock. The property is locked and cannot be changed by children.");
		else
			ImGui.AttachTooltip("Click to lock. The property is unlocked and can be changed by children.");
		
		ImGui.PopStyleColor(3);
		ImGui.PopStyleVar(1);

		return result;
	}

	/// <summary>
	/// Converts a variable name to a pretty name as good as reasonably possible.
	/// </summary>
	/// <param name="uglyName">The name of a variable to prettify.</param>
	/// <returns>The pretty string.</returns>
	public static void ToPrettyName(StringView uglyName, String outPrettyName)
	{
		outPrettyName.PrepareBuffer(uglyName.Length);
		outPrettyName.Clear();

	    bool wasUpper = false;
	    bool inWord = false;
	    bool inNumber = false;

	    for (char8 c in uglyName)
	    {
	        if (c.IsLetter)
	        {
	            if (inNumber)
	            {
	                outPrettyName.Append(' ');
	                inNumber = false;
	            }
	        
	            bool newWord = !inWord;
	                    
	            if (c.IsUpper && !wasUpper)
	            {
	                newWord = true;
	                wasUpper = true;
	            
	                if (inWord)
	                {
	                    outPrettyName.Append(' ');
	                }
	            }
	            else if (c.IsLower)
	            {
	                wasUpper = false;
	            }
	        
	            outPrettyName.Append(newWord ? c.ToUpper : c.ToLower);
	        
	            inWord = true;
	        }
	        else if (c.IsDigit)
	        {
	            if (inWord)
	            {
	                outPrettyName.Append(' ');
	                inWord = false;
	                inNumber = true;
	            }
	        
	            outPrettyName.Append(c);
	        }
	        else if (inWord || inNumber)
	        {
	            outPrettyName.Append(' ');
	            inWord = false;
	            inNumber = false;
	            wasUpper = false;
	        }
	    }
	}
}