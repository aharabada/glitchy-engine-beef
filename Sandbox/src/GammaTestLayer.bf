using GlitchyEngine;
using GlitchyEngine.Events;
using GlitchyEngine.ImGui;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using GlitchyEngine.Renderer.Text;
using ImGui;
using System;

namespace Sandbox
{
	class GammaTestLayer : Layer
	{
		RasterizerState _rasterizerState ~ _?.ReleaseRef();

		GraphicsContext _context ~ _?.ReleaseRef();
		DepthStencilTarget _depthTarget ~ _?.ReleaseRef();

		Texture2D _checkerTexture ~ _?.ReleaseRef();

		Texture2D _smallLines ~ _?.ReleaseRef();
		Texture2D _gammaCorrectionBrightness ~ _?.ReleaseRef();
		Texture2D _zeroPointFive ~ _?.ReleaseRef();

		BlendState _alphaBlendState ~ _?.ReleaseRef();

		DepthStencilState _depthStencilState ~ _.ReleaseRef();

		Font _font ~ _.ReleaseRef();

		FontRenderer.PreparedText _smallLinesInfo ~ _.ReleaseRef();
		FontRenderer.PreparedText _halfQuadInfo ~ _.ReleaseRef();
		FontRenderer.PreparedText _explanation ~ _.ReleaseRef();

		[AllowAppend]
		public this() : base("Example")
		{
			_context = Application.Get().Window.Context..AddRef();

			// Create rasterizer state
			GlitchyEngine.Renderer.RasterizerStateDescription rsDesc = .(.Solid, .Back, false, 0);
			_rasterizerState = new RasterizerState(rsDesc);

			_depthTarget = new DepthStencilTarget(_context.SwapChain.Width, _context.SwapChain.Height);

			//_checkerTexture = new Texture2D("content/Textures/Checkerboard.dds");
			//_smallLines = new Texture2D("content/GammaTest/SmallLines.png");
			//_gammaCorrectionBrightness = new Texture2D("content/GammaTest/gamma_correction_brightness.png");

			//_zeroPointFive = new Texture2D("content/GammaTest/zeroPointFive.png");

			let sampler = SamplerStateManager.GetSampler(
				SamplerStateDescription()
				{
					MagFilter = .Point,
					AddressModeU = .Wrap,
					AddressModeV = .Wrap,
				});
			
			_checkerTexture.SamplerState = sampler;

			_smallLines.SamplerState = SamplerStateManager.PointClamp;

			sampler.ReleaseRef();

			BlendStateDescription blendDesc = .();
			blendDesc.RenderTarget[0] = .(true, .SourceAlpha, .InvertedSourceAlpha, .Add, .SourceAlpha, .InvertedSourceAlpha, .Add, .All);
			_alphaBlendState = new BlendState(blendDesc);

			DepthStencilStateDescription dssDesc = .()
				{
					DepthEnabled = false
				};
			_depthStencilState = new DepthStencilState(dssDesc);

			_font = new Font(@"C:\Windows\Fonts\arial.ttf", 24);

			_smallLinesInfo = FontRenderer.PrepareText(_font, "Is the bottom center quad the same color as the left and right columns?", 24);

			_halfQuadInfo = FontRenderer.PrepareText(_font, "Is this quad roughly the same color \nas the column next to it?\nIs it the same Color as the bottom quad to the left?", 24);

			_explanation = FontRenderer.PrepareText(_font, "If all these questions can be answered with \"yes\" then gamma correction is doing it's job!", 24);
			
			camera = new OrthographicCamera();
			camera.Width = _context.SwapChain.Width;
			camera.Height = _context.SwapChain.Height;
			camera.FarPlane = 10;
			camera.NearPlane = -10;
			camera.Position = .(_context.SwapChain.Width, _context.SwapChain.Height, 0) / 2;
			camera.Update();
		}

		OrthographicCamera camera ~ delete _;

		public override void Update(GameTime gameTime)
		{
			RenderCommand.Clear(null, .(0f, 0f, 0f));
			RenderCommand.Clear(_depthTarget, .Depth, 1.0f, 0);

			// Draw test geometry
			RenderCommand.SetRenderTarget(null);
			RenderCommand.SetDepthStencilTarget(_depthTarget);
			RenderCommand.BindRenderTargets();

			RenderCommand.SetRasterizerState(_rasterizerState);

			RenderCommand.SetViewport(_context.SwapChain.BackbufferViewport);

			Renderer2D.BeginScene(camera, .BackToFront);

			RenderCommand.SetBlendState(_alphaBlendState);
			RenderCommand.SetDepthStencilState(_depthStencilState);

			//Renderer2D.DrawQuad(float3(0, 0, 1), float2(8), 0, _checkerTexture, .White, .(0, 0, 1, 1));
			//Renderer2D.DrawQuad(float3(0, 0, 0), float2(_smallLines.Width, _smallLines.Height), 0, _smallLines, .White, .(0, 0, 1, 1));

			Renderer2D.DrawQuad(float3(_smallLines.Width / 2, _smallLines.Height / 2, 0), float2(_smallLines.Width, _smallLines.Height), 0, _smallLines, .White, .(0, 0, 1, 1));
			
			FontRenderer.DrawText(_smallLinesInfo, 0, _smallLines.Height);

			float f = _smallLines.Height / 2;

			Renderer2D.DrawQuad(float3(_smallLines.Width * 2, f / 2, 0), float2(f, f), 0, .(0.5f, 0.5f, 0.5f));
			Renderer2D.DrawQuad(float3(_smallLines.Width * 2, 3 * f / 2 + 1, 0), float2(f, f), 0, _zeroPointFive);
			//Renderer2D.DrawQuad(float3(_smallLines.Width + f / 2, 3 * f / 2, 0), float2(f, f), 0, .(0.25f, 0.25f, 0.25f));

			//FontRenderer.DrawText(_halfQuadInfo, _smallLines.Width + f, f / 2);
			
			//Renderer2D.DrawQuad(float3(_gammaCorrectionBrightness.Width / 2, _smallLines.Height * 1.5f, 0), float2(_gammaCorrectionBrightness.Width, _gammaCorrectionBrightness.Height), 0, _gammaCorrectionBrightness, .White, .(0, 0, 1, 1));
			
			//Renderer2D.DrawQuad(float3(_smallLines.Width + f / 2, 500, 0), float2(f, f), 0, .(0.1f, 0.1f, 0.1f));
			//Renderer2D.DrawQuad(float3(_gammaCorrectionBrightness.Width / 2, 0, 0), float2(_gammaCorrectionBrightness.Width, _gammaCorrectionBrightness.Height), 0, _gammaCorrectionBrightness, .White, .(0, 0, 1, 1));

			//Renderer2D.DrawQuad(float3(0, -200, 0), float2(100, 100), 0, .(0.5f, 0.5f, 0.5f));
			//Renderer2D.DrawQuad(float3(0, -300, 0), float2(100, 100), 0, .(0.25f, 0.25f, 0.25f));

			//Renderer2D.DrawQuad(float3(0, _gammaCorrectionBrightness.Height, 0), float2(_gammaCorrectionBrightness.Width, _gammaCorrectionBrightness.Height), 0, _gammaCorrectionBrightness, .(2, 2, 2), .(0, 0, 1, 1));

			Renderer2D.EndScene();
		}

		public override void OnEvent(Event event)
		{
			EventDispatcher dispatcher = EventDispatcher(event);

			dispatcher.Dispatch<ImGuiRenderEvent>(scope (e) => OnImGuiRender(e));

			dispatcher.Dispatch<WindowResizeEvent>(scope (e) => OnWindowResize(e));
		}

		private bool OnImGuiRender(ImGuiRenderEvent e)
		{
			return false;
		}

		private bool OnWindowResize(WindowResizeEvent e)
		{
			_depthTarget.ReleaseRef();
			_depthTarget = new DepthStencilTarget(_context.SwapChain.Width, _context.SwapChain.Height);

			camera.Width = _context.SwapChain.Width;
			camera.Height = _context.SwapChain.Height;
			camera.Position = .(_context.SwapChain.Width, _context.SwapChain.Height, 0) / 2;
			camera.Update();

			return false;
		}
	}
}