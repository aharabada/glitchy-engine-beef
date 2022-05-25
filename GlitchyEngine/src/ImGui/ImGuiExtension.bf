using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using System;

namespace ImGui
{
	extension ImGui
	{
		extension Vec2
		{
			public static explicit operator Vector2(Vec2 v) => .(v.x, v.y);
			public static explicit operator Vec2(Vector2 v) => .(v.X, v.Y);
		}

		extension Vec4
		{
			public static explicit operator Vector4(Vec4 v) => .(v.x, v.y, v.z, v.w);
			public static explicit operator Vec4(Vector4 v) => .(v.X, v.Y, v.Z, v.W);
		}

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

		public static void Image(RenderTarget2D texture, Vec2 size, Vec2 uv0 = Vec2.Zero, Vec2 uv1 = Vec2.Ones, Vec4 tint_col = Vec4.Ones, Vec4 border_col = Vec4.Zero)
		{
			Image(texture.GetViewBinding(), size, uv0, uv1, tint_col, border_col);
		}

		public static extern void Image(TextureViewBinding textureViewBinding, Vec2 size, Vec2 uv0 = Vec2.Zero, Vec2 uv1 = Vec2.Ones, Vec4 tint_col = Vec4.Ones, Vec4 border_col = Vec4.Zero);

		public static void TextUnformatted(StringView text) => TextUnformattedImpl(text.Ptr, text.Ptr + text.Length);
		
		public static void PushID(StringView id) => PushID(id.Ptr, id.Ptr + id.Length);

		/// Releases references that accumulated calls like ImGui::Image
		protected internal static extern void CleanupFrame();

		/// Control to edit a vector 2 with drag functionality and reset buttons
		public static bool EditVector2(StringView label, ref Vector2 value, Vector2 resetValues = .Zero, float dragSpeed = 0.1f, float columnWidth = 100f, Vector2 minValue = .Zero, Vector2 maxValue = .Zero)
		{
			return EditVector<2>(label, ref *(float[2]*)&value, (float[2])resetValues, dragSpeed, columnWidth, (float[2])minValue, (float[2])maxValue);
		}

		/// Control to edit a vector 3 with drag functionality and reset buttons
		public static bool EditVector3(StringView label, ref Vector3 value, Vector3 resetValues = .Zero, float dragSpeed = 0.1f, float columnWidth = 100f, Vector3 minValue = .Zero, Vector3 maxValue = .Zero)
		{
			return EditVector<3>(label, ref *(float[3]*)&value, (float[3])resetValues, dragSpeed, columnWidth, (float[3])minValue, (float[3])maxValue);
		}

		/// Control to edit a vector 4 with drag functionality and reset buttons
		public static bool EditVector4(StringView label, ref Vector4 value, Vector4 resetValues = .Zero, float dragSpeed = 0.1f, float columnWidth = 100f, Vector4 minValue = .Zero, Vector4 maxValue = .Zero)
		{
			return EditVector<4>(label, ref *(float[4]*)&value, (float[4])resetValues, dragSpeed, columnWidth, (float[4])minValue, (float[4])maxValue);
		}

		public static bool EditVector<NumComponents>(StringView label, ref float[NumComponents] value, float[NumComponents] resetValues = .(), float dragSpeed = 0.1f, float columnWidth = 100f, float[NumComponents] minValue = .(), float[NumComponents] maxValue = .()) where NumComponents : const int32
		{
			const String[?] componentNames = .("X", "Y", "Z", "W");
			const String[?] componentIds = .("##X", "##Y", "##Z", "##W");

			(Color Default, Color Hovered, Color Active)[?] ButtonColors = .(
				(Color(230, 25, 45), Color(150, 25, 45), Color(230, 90, 90)),
				(Color(50, 190, 15), Color(50, 120, 15), Color(116, 190, 99)),
				(Color(55, 55, 230), Color(55, 55, 150), Color(90, 90, 230)),
				(Color(230, 25, 45), Color(230, 25, 45), Color(230, 25, 45)));

			bool changed = false;

			PushID(label);
			defer PopID();

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

				PushStyleColor(.Button, ButtonColors[i].Default.Value);
				PushStyleColor(.ButtonHovered, ButtonColors[i].Hovered.Value);
				PushStyleColor(.ButtonActive, ButtonColors[i].Active.Value);
	
				if (Button(componentNames[i], buttonSize))
				{
					value[i] = resetValues[i];
					changed = true;
				}
	
				SameLine();
	
				if (DragFloat(componentIds[i], &value[i], dragSpeed, minValue[i], maxValue[i]))
					changed = true;
	
				PopItemWidth();
				PopStyleColor(3);
			}

			PopStyleVar();

			return changed;
		}
	}
}
