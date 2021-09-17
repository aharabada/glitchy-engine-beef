using GlitchyEngine.Renderer;

namespace ImGui
{
	using internal GlitchyEngine.Renderer;

	extension ImGui
	{
		public static override void Image(Texture2D texture, Vec2 size, Vec2 uv0 = Vec2.Zero, Vec2 uv1 = Vec2.Ones, Vec4 tint_col = Vec4.Ones, Vec4 border_col = Vec4.Zero)
		{
			ImGui.Image(texture.nativeResourceView, size, uv0, uv1, tint_col, border_col);
		}
	}
}
