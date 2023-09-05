using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using System;
using GlitchyEngine;
using System.Collections;

namespace GlitchyEngine.Math
{
	extension ColorRGBA
	{
		internal uint32 ImGuiU32 => ImGui.ImGui.ColorConvertFloat4ToU32((.)(float4)this);
	}
}

namespace ImGui
{
	using internal GlitchyEngine.Math;

	extension ImGui
	{
		extension Vec2
		{
			public static explicit operator float2(Vec2 v) => .(v.x, v.y);
			public static explicit operator Vec2(float2 v) => .(v.X, v.Y);
		}
	
		extension Vec4
		{
			public static explicit operator float4(Vec4 v) => .(v.x, v.y, v.z, v.w);
			public static explicit operator Vec4(float4 v) => .(v.X, v.Y, v.Z, v.W);
		}

		/*public static bool IsItemJustDeactivated()
		{
		    return IsItemDeactivatedAfterEdit();
		}

		public static bool IsItemActiveLastFrame()
		{
		    Context* g = GetCurrentContext();
		    if (g.ActiveIdPreviousFrame != 0)
		        return g.ActiveIdPreviousFrame == g.CurrentWindow.DC.LastItemId;

		    return false;
		}

		public static bool IsItemJustActivated()
		{
		    return IsItemActive() && !IsItemActiveLastFrame();
		}

		public static bool IsItemEditing()
		{
		    return IsItemActive();
		}*/

		// TODO: Color-functions
		public static bool ColorEdit3(char* label, ref ColorRGB col, ColorEditFlags flags = (ColorEditFlags) 0) => ColorEdit3Impl(label, *(float[3]*)&col, flags);
		public static bool ColorEdit3(char* label, ref ColorRGBA col, ColorEditFlags flags = (ColorEditFlags) 0) => ColorEdit3Impl(label, *(float[3]*)&col, flags);
	
		public static bool ColorEdit4(char* label, ref ColorRGBA col, ColorEditFlags flags = (ColorEditFlags) 0) => ColorEdit4Impl(label, *(float[4]*)&col, flags);
	
	    public static bool ColorPicker3(char* label, ref ColorRGB col, ColorEditFlags flags = (ColorEditFlags) 0) => ColorPicker3Impl(label, *(float[3]*)&col, flags);
	    public static bool ColorPicker3(char* label, ref ColorRGBA col, ColorEditFlags flags = (ColorEditFlags) 0) => ColorPicker3Impl(label, *(float[3]*)&col, flags);
		
		public static bool ColorPicker4(char* label, ref ColorRGBA col, ColorEditFlags flags = (ColorEditFlags) 0, float* ref_col = null) => ColorPicker4Impl(label, *(float[4]*)&col, flags, ref_col);
	
		public static void Image(Texture2D texture, Vec2 size, Vec2 uv0 = Vec2.Zero, Vec2 uv1 = Vec2.Ones, Vec4 tint_col = Vec4.Ones, Vec4 border_col = Vec4.Zero)
		{
			Image(texture.GetViewBinding(), size, uv0, uv1, tint_col, border_col);
		}
	
		public static void Image(SubTexture2D subTexture, Vec2 size, Vec2 uv0 = Vec2.Zero, Vec2 uv1 = Vec2.Ones, Vec4 tint_col = Vec4.Ones, Vec4 border_col = Vec4.Zero)
		{
			if (uv0 != .Zero || uv1 != .Ones)
				Runtime.NotImplemented();
	
			float2 v = (.)subTexture.TexCoords.XY + subTexture.TexCoords.ZW;
	
			Image(subTexture.Texture.GetViewBinding(), size, (.)subTexture.TexCoords.XY, (.)v, tint_col, border_col);
		}
	
		public static void Image(RenderTarget2D texture, Vec2 size, Vec2 uv0 = Vec2.Zero, Vec2 uv1 = Vec2.Ones, Vec4 tint_col = Vec4.Ones, Vec4 border_col = Vec4.Zero)
		{
			Image(texture.GetViewBinding(), size, uv0, uv1, tint_col, border_col);
		}
	
		public static extern void Image(TextureViewBinding textureViewBinding, Vec2 size, Vec2 uv0 = Vec2.Zero, Vec2 uv1 = Vec2.Ones, Vec4 tint_col = Vec4.Ones, Vec4 border_col = Vec4.Zero);
	
		public static bool ImageButton(char8* id, SubTexture2D subTexture, Vec2 size, Vec2 uv0 = Vec2.Zero, Vec2 uv1 = Vec2.Ones, Vec4 bg_col = Vec4.Zero, Vec4 tint_col = Vec4.Ones)
		{
			if (uv0 != .Zero || uv1 != .Ones)
				Runtime.NotImplemented();
	
			float2 v = (.)subTexture.TexCoords.XY + subTexture.TexCoords.ZW;
	
			return ImageButton(id, subTexture.Texture.GetViewBinding(), size, (.)subTexture.TexCoords.XY, (.)v, bg_col, tint_col);
		}

		public static extern bool ImageButton(char8* id, TextureViewBinding textureViewBinding, Vec2 size, Vec2 uv0 = Vec2.Zero, Vec2 uv1 = Vec2.Ones, Vec4 bg_col = Vec4.Zero, Vec4 tint_col = Vec4.Ones);

		public static bool ImageButtonEx(uint32 id, SubTexture2D subTexture, Vec2 size, Vec2 uv0 = Vec2.Zero, Vec2 uv1 = Vec2.Ones, Vec4 bg_col = Vec4.Zero, Vec4 tint_col = Vec4.Ones)
		{
			if (uv0 != .Zero || uv1 != .Ones)
				Runtime.NotImplemented();

			float2 v = (.)subTexture.TexCoords.XY + subTexture.TexCoords.ZW;

			return ImageButtonEx(id, subTexture.Texture.GetViewBinding(), size, (.)subTexture.TexCoords.XY, (.)v, bg_col, tint_col);
		}
		
		public static extern bool ImageButtonEx(uint32 id, TextureViewBinding textureViewBinding, Vec2 size, Vec2 uv0 = Vec2.Zero, Vec2 uv1 = Vec2.Ones, Vec4 bg_col = Vec4.Zero, Vec4 tint_col = Vec4.Ones);

		public static void TextUnformatted(StringView text) => TextUnformattedImpl(text.Ptr, text.Ptr + text.Length);
		
		public static void PushID(StringView id) => PushID(id.Ptr, id.Ptr + id.Length);
	
		/// Releases references that accumulated calls like ImGui::Image
		protected internal static extern void CleanupFrame();
	
		/// Control to edit a vector 2 with drag functionality and reset buttons
		public static bool Editfloat2(StringView label, ref float2 value, float2 resetValues = .Zero, float dragSpeed = 0.1f, float columnWidth = 100f, float2 minValue = .Zero, float2 maxValue = .Zero, bool2 componentEnabled = true)
		{
			return EditVector<2>(label, ref *(float[2]*)&value, (float[2])resetValues, dragSpeed, columnWidth, (float[2])minValue, (float[2])maxValue, (bool[2])componentEnabled);
		}
	
		/// Control to edit a vector 3 with drag functionality and reset buttons
		public static bool Editfloat3(StringView label, ref float3 value, float3 resetValues = .Zero, float dragSpeed = 0.1f, float columnWidth = 100f, float3 minValue = .Zero, float3 maxValue = .Zero, bool3 componentEnabled = true)
		{
			return EditVector<3>(label, ref *(float[3]*)&value, (float[3])resetValues, dragSpeed, columnWidth, (float[3])minValue, (float[3])maxValue, (bool[3])componentEnabled);
		}
	
		/// Control to edit a vector 4 with drag functionality and reset buttons
		public static bool Editfloat4(StringView label, ref float4 value, float4 resetValues = .Zero, float dragSpeed = 0.1f, float columnWidth = 100f, float4 minValue = .Zero, float4 maxValue = .Zero, bool4 componentEnabled = true)
		{
			return EditVector<4>(label, ref *(float[4]*)&value, (float[4])resetValues, dragSpeed, columnWidth, (float[4])minValue, (float[4])maxValue, (bool[4])componentEnabled);
		}
	
		static (ColorRGBA Default, ColorRGBA Hovered, ColorRGBA Active)[?] VectorButtonColors = .(
				(.(230, 25, 45), .(150, 25, 45), .(230, 90, 90)),
				(.(50, 190, 15), .(50, 120, 15), .(116, 190, 99)),
				(.(55, 55, 230), .(55, 55, 150), .(90, 90, 230)),
				(.(230, 25, 45), .(230, 25, 45), .(230, 25, 45)));
	
		public static bool EditVector<NumComponents>(StringView label, ref float[NumComponents] value, float[NumComponents] resetValues = .(), float dragSpeed = 0.1f, float columnWidth = 100f, float[NumComponents] minValue = .(), float[NumComponents] maxValue = .(), bool[NumComponents] componentEnabled = .()) where NumComponents : const int32
		{
			const String[?] componentNames = .("X", "Y", "Z", "W");
			const String[?] componentIds = .("##X", "##Y", "##Z", "##W");

			static int mouseLockId = 0;

			bool changed = false;
			bool deactivated = false;
	
			PushID(label);
			defer PopID();

			int currentId = ImGui.GetID("");
	
			Columns(2);
			defer Columns(1);
			SetColumnWidth(0, columnWidth);
	
			TextUnformatted(label);
	
			NextColumn();
	
			PushMultiItemsWidths(NumComponents, CalcItemWidth());
			
			float lineHeight = GetFont().FontSize + GetStyle().FramePadding.y * 2.0f;
			ImGui.Vec2 buttonSize = .(lineHeight + 3.0f, lineHeight);
	
			PushStyleVar(.ItemSpacing, Vec2.Zero);
			
			for (int i < NumComponents)
			{
				if (i > 0)
				{
					SameLine();
				}
	
				PushStyleColor(.Button, VectorButtonColors[i].Default.ImGuiU32);
				PushStyleColor(.ButtonHovered, VectorButtonColors[i].Hovered.ImGuiU32);
				PushStyleColor(.ButtonActive, VectorButtonColors[i].Active.ImGuiU32);

				ImGui.BeginDisabled(!componentEnabled[i]);

				if (Button(componentNames[i], buttonSize))
				{
					value[i] = resetValues[i];
					changed = true;
				}
	
				SameLine();

				if (DragFloat(componentIds[i], &value[i], dragSpeed, minValue[i], maxValue[i]))
				{
					changed = true;

					/*if (mouseLockId != currentId)
					{
						mouseLockId = currentId;

						Mouse.LockCurrentPosition(mouseLockId);
					}*/
				}
				
				ImGui.EndDisabled();
				/*if (IsItemDeactivatedAfterEdit())
				{
					deactivated = true;
				}*/
	
				PopItemWidth();
				PopStyleColor(3);
			}
	
			PopStyleVar();

			/*if (mouseLockId == currentId && deactivated)
			{
				Mouse.UnlockPosition(mouseLockId);
				mouseLockId = 0;
			}*/
	
			return changed;
		}
	
		/// Draws a rectangle with the given color.
		public static void DrawRect(Vec2 min, Vec2 max, Color color)
		{
			ImGui.GetForegroundDrawList().AddRect(min, max, ImGui.GetColorU32(color.Value));
		}

		/// Provides a combo Box to select an enum value.
		public static bool EnumCombo<T>(StringView label, ref T selectedValue) where T : enum
		{
			String selectedValueString = scope .();
			selectedValue.ToString(selectedValueString);
			// TODO: make selectedValue human readable

			bool changed = false;

			if (ImGui.BeginCombo(label.ToScopeCStr!(), selectedValueString))
			{
				for (let (name, value) in Enum.GetEnumerator<T>())
				{
				    ImGui.PushID(name);

				    if (ImGui.Selectable(name.ToScopeCStr!(), selectedValue == value))
					{
				        selectedValue = value;
						changed = true;
					}

				    ImGui.PopID();
				}

				ImGui.EndCombo();
			}

			return changed;
		}

		/// Provides a tooltip that will be show when the previously defined Widget is hovered.
		public static void AttachTooltip(StringView tooltip)
		{
			if (!ImGui.IsItemHovered())
				return;

			ImGui.BeginTooltip();

			ImGui.TextUnformatted(tooltip);

			ImGui.EndTooltip();
		}

		[Comptime]
		private static DataType GetDataType<T>()
		{
			DataType dataType = .COUNT;

			switch (typeof(T))
			{
			case typeof(int8):
				dataType = .S8;
			case typeof(int16):
				dataType = .S16;
			case typeof(int32):
				dataType = .S32;
			case typeof(int64):
				dataType = .S64;
			case typeof(int):
				if (sizeof(int) == 8)
					dataType = .S64;
				else if (sizeof(int) == 4)
					dataType = .S32;

			case typeof(uint8):
				dataType = .U8;
			case typeof(uint16):
				dataType = .U16;
			case typeof(uint32):
				dataType = .U32;
			case typeof(uint64):
				dataType = .U64;
			case typeof(uint):
				if (sizeof(uint) == 8)
					dataType = .U64;
				else if (sizeof(uint) == 4)
					dataType = .U32;
			//default:
			//	Runtime.Assert(dataType != .COUNT);
				//Log.EngineLogger.Assert(dataType != .COUNT, "Unknown data type.");
			}

			return dataType;
		}

		// TODO: Add support for floats
		public static bool DragScalar<T>(char8* label, ref T value, float dragSpeed = (float) 1.0f, T minValue = typeof(T).MinValue, T maxValue = typeof(T).MaxValue, char8* format = null, SliderFlags sliderFlags = .None) where T : IInteger
		{
			DataType dataType = GetDataType<T>();

#unwarn		
			return DragScalar(label, dataType, &value, dragSpeed, &minValue, &maxValue, format, sliderFlags);
		}

		// TODO: Add support for floats
		public static bool SliderScalar<T>(char8* label, ref T value, T minValue = typeof(T).MinValue, T maxValue = typeof(T).MaxValue, char8* format = null, SliderFlags sliderFlags = .None) where T : IInteger
		{
			DataType dataType = GetDataType<T>();

#unwarn		
			return SliderScalar(label, dataType, &value, &minValue, &maxValue, format, sliderFlags);
		}
	}
}