using GlitchyEngine.Math;
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
	}
}
