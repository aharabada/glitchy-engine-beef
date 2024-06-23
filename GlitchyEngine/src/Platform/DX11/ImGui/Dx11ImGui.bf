#if GE_GRAPHICS_DX11

using GlitchyEngine.Renderer;
using System.Collections;
using DirectX.D3D11;

namespace ImGui
{
	using internal GlitchyEngine.Renderer;

	extension ImGui
	{
		static List<ID3D11ShaderResourceView*> _resourceViews = new .() ~ delete _;

		public static override void Image(TextureViewBinding textureViewBinding, Vec2 size, Vec2 uv0 = Vec2.Zero, Vec2 uv1 = Vec2.Ones, Vec4 tint_col = Vec4.Ones, Vec4 border_col = Vec4.Zero)
		{
			var view = textureViewBinding._nativeShaderResourceView..AddRef();
			_resourceViews.Add(view);

			ImGui.Image(view, size, uv0, uv1, tint_col, border_col);

			textureViewBinding.Release();
		}

		public static override bool ImageButton(char8* id, TextureViewBinding textureViewBinding, Vec2 imageSize, Vec2 uv0 = Vec2.Zero, Vec2 uv1 = Vec2.Ones, Vec4 bg_col = Vec4.Zero, Vec4 tint_col = Vec4.Ones)
		{
			var view = textureViewBinding._nativeShaderResourceView..AddRef();
			_resourceViews.Add(view);

			bool pressed = ImGui.ImageButton(id, view, imageSize, uv0, uv1, bg_col, tint_col);

			textureViewBinding.Release();

			return pressed;
		}

		public static override bool ImageButtonEx(uint32 id, TextureViewBinding textureViewBinding, Vec2 imageSize, Vec2 uv0 = Vec2.Zero, Vec2 uv1 = Vec2.Ones, Vec4 bg_col = Vec4.Zero, Vec4 tint_col = Vec4.Ones)
		{
			var view = textureViewBinding._nativeShaderResourceView..AddRef();
			_resourceViews.Add(view);

			bool pressed = ImGui.ImageButtonEx(id, view, imageSize, uv0, uv1, bg_col, tint_col);

			textureViewBinding.Release();

			return pressed;
		}

		protected internal static override void CleanupFrame()
		{
			for(var view in _resourceViews)
			{
				view.Release();
			}

			_resourceViews.Clear();
		}
	}
}

#endif
