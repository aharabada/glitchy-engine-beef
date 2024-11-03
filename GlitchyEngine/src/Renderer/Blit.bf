using GlitchyEngine.Content;

namespace GlitchyEngine.Renderer;

static class Blit
{
	public static AssetHandle<Effect> _copyEffect;

	internal static void Init()
	{
		_copyEffect = Content.LoadAsset("Resources/Shaders/Copy.hlsl");
	}

	public static void Blit(Texture2D source, RenderTarget2D destination, Effect blitEffect = _copyEffect, Viewport? viewport = null)
	{
		RenderCommand.UnbindRenderTargets();
		RenderCommand.SetRenderTarget(destination);
		RenderCommand.BindRenderTargets();
		RenderCommand.SetViewport(viewport ?? Viewport(0, 0, destination.Width, destination.Height));

		blitEffect.SetTexture("Texture", source);
		blitEffect.ApplyChanges();
		blitEffect.Bind();

		FullscreenQuad.Draw();
	}
}
