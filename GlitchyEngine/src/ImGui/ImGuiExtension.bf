using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using System;

namespace ImGui
{
	extension ImGui
	{
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
	}
}
