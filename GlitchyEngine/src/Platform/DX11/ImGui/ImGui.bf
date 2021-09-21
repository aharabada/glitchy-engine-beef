using GlitchyEngine.Renderer;
using System.Collections;
using DirectX.D3D11;

namespace ImGui
{
	using internal GlitchyEngine.Renderer;

	extension ImGui
	{
		static List<ID3D11ShaderResourceView*> _resourceViews = new .() ~ delete _;

		public static override void Image(Texture2D texture, Vec2 size, Vec2 uv0 = Vec2.Zero, Vec2 uv1 = Vec2.Ones, Vec4 tint_col = Vec4.Ones, Vec4 border_col = Vec4.Zero)
		{
			var view = texture.nativeResourceView..AddRef();
			_resourceViews.Add(view);

			ImGui.Image(view, size, uv0, uv1, tint_col, border_col);
		}

		public static override void Image(RenderTarget2D texture, Vec2 size, Vec2 uv0 = Vec2.Zero, Vec2 uv1 = Vec2.Ones, Vec4 tint_col = Vec4.Ones, Vec4 border_col = Vec4.Zero)
		{
			var view = texture._nativeResourceView..AddRef();
			_resourceViews.Add(view);

			ImGui.Image(view, size, uv0, uv1, tint_col, border_col);
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
