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

		public static extern void Image(Texture2D texture, Vec2 size, Vec2 uv0 = Vec2.Zero, Vec2 uv1 = Vec2.Ones, Vec4 tint_col = Vec4.Ones, Vec4 border_col = Vec4.Zero);
		// Wouldn't be necesseary if RenderTarget2D was Texture2D
		public static extern void Image(RenderTarget2D texture, Vec2 size, Vec2 uv0 = Vec2.Zero, Vec2 uv1 = Vec2.Ones, Vec4 tint_col = Vec4.Ones, Vec4 border_col = Vec4.Zero);

		public static void TextUnformatted(StringView text) => TextUnformattedImpl(text.Ptr, text.Ptr + text.Length);
		
		public static void PushID(StringView id) => PushID(id.Ptr, id.Ptr + id.Length);

		/// Releases references that accumulated calls like ImGui::Image
		protected internal static extern void CleanupFrame();

		/// Control to edit a vector 3 with drag functionality and reset buttons
		public static bool EditVector3(StringView label, ref Vector3 value, Vector3 resetValues = .Zero, float dragSpeed = 0.1f, float columnWidth = 100f)
		{
			bool changed = false;

			PushID(label);
			defer PopID();

			Columns(2);
			defer Columns(1);
			SetColumnWidth(0, columnWidth);

			TextUnformatted(label);

			NextColumn();

			PushMultiItemsWidths(3, CalcItemWidth());
			PushStyleVar(.ItemSpacing, Vec2.Zero);
			defer PopStyleVar();

			float lineHeight = GetFont().FontSize + GetStyle().FramePadding.y * 2.0f;
			ImGui.Vec2 buttonSize = .(lineHeight + 3.0f, lineHeight);

			PushStyleColor(.Button, Color(230, 25, 45).Value);
			PushStyleColor(.ButtonHovered, Color(150, 25, 45).Value);
			PushStyleColor(.ButtonActive, Color(230, 120, 130).Value);

			if (Button("X", buttonSize))
			{
				value.X = resetValues.X;
				changed = true;
			}

			SameLine();

			if (DragFloat("##X", &value.X, dragSpeed))
				changed = true;

			PopItemWidth();
			SameLine();

			PopStyleColor(3);
			PushStyleColor(.Button, Color(50, 190, 15).Value);
			PushStyleColor(.ButtonHovered, Color(50, 120, 15).Value);
			PushStyleColor(.ButtonActive, Color(116, 190, 99).Value);

			if (Button("Y", buttonSize))
			{
				value.Y = resetValues.Y;
				changed = true;
			}
			
			SameLine();

			if (DragFloat("##Y", &value.Y, dragSpeed))
				changed = true;
			
			PopItemWidth();
			SameLine();
			
			PopStyleColor(3);
			PushStyleColor(.Button, Color(55, 55, 230).Value);
			PushStyleColor(.ButtonHovered, Color(55, 55, 150).Value);
			PushStyleColor(.ButtonActive, Color(90, 90, 230).Value);

			if (Button("Z", buttonSize))
			{
				value.Z = resetValues.Z;
				changed = true;
			}
			
			SameLine();

			if (DragFloat("##Z", &value.Z, dragSpeed))
				changed = true;
			
			PopItemWidth();

			PopStyleColor(3);

			return changed;
		}
	}
}
