using System;
using GlitchyEngine;
using GlitchyEngine.Events;
using System.Diagnostics;
using GlitchLog;
using GlitchyEngine.ImGui;
using ImGui;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using GlitchyEngine.World;
using GlitchyEngine.Renderer.Text;
using System.IO;
using msdfgen;

namespace Sandbox
{
	class ExampleLayer2D : Layer
	{
		RasterizerState _rasterizerState ~ _?.ReleaseRef();

		GraphicsContext _context ~ _?.ReleaseRef();
		DepthStencilTarget _depthTarget ~ _?.ReleaseRef();

		Texture2D _checkerTexture ~ _?.ReleaseRef();

		BlendState _alphaBlendState ~ _?.ReleaseRef();

		TextureViewer _textureViewer ~ delete _;
		
		OrthographicCameraController cameraController ~ delete _;

		Font fonty ~ _.ReleaseRef();
		
		ColorRGBA _squareColor0 = ColorRGBA.CornflowerBlue;
		ColorRGBA _squareColor1;

		[AllowAppend]
		public this() : base("Example")
		{
			Application.Get().Window.IsVSync = false;

			_context = Application.Get().Window.Context..AddRef();

			// Create rasterizer state
			GlitchyEngine.Renderer.RasterizerStateDescription rsDesc = .(.Solid, .Back, false, 0);
			_rasterizerState = new RasterizerState(rsDesc);

			_depthTarget = new DepthStencilTarget(_context.SwapChain.Width, _context.SwapChain.Height);

			_checkerTexture = new Texture2D("content/Textures/Checkerboard.dds");

			let sampler = SamplerStateManager.GetSampler(
				SamplerStateDescription()
				{
					MagFilter = .Point,
					AddressModeU = .Wrap,
					AddressModeV = .Wrap,
				});
			
			_checkerTexture.SamplerState = sampler;

			sampler.ReleaseRef();

			BlendStateDescription blendDesc = .();
			blendDesc.RenderTarget[0] = .(true, .SourceAlpha, .InvertedSourceAlpha, .Add, .SourceAlpha, .InvertedSourceAlpha, .Add, .All);
			_alphaBlendState = new BlendState(blendDesc);

			fonty = new Font("C:\\Windows\\Fonts\\arial.ttf", 64, true, 'A', 16);
			var japanese = new Font("C:\\Windows\\Fonts\\YuGothM.ttc", 64, true, '\0', 1);
			var emojis = new Font("C:\\Windows\\Fonts\\seguiemj.ttf", 64, true, '😂' - 10, 1);
			var mathstuff = new Font("C:\\Windows\\Fonts\\cambria.ttc", 64, true, 'α', 1);
			fonty.Fallback = japanese..ReleaseRefNoDelete();
			japanese.Fallback = emojis..ReleaseRefNoDelete();
			emojis.Fallback = mathstuff..ReleaseRefNoDelete();

			_textureViewer = new TextureViewer();

			cameraController = new OrthographicCameraController(16 / 9f);
		}

		public override void Update(GameTime gameTime)
		{
			cameraController.Update(gameTime);

			RenderCommand.Clear(null, .(0.2f, 0.2f, 0.2f));
			RenderCommand.Clear(_depthTarget, 1.0f, 0, .Depth);
			
			// Draw test geometry
			_context.SetRenderTarget(null);
			_context.SetDepthStencilTarget(_depthTarget);
			_context.BindRenderTargets();

			_context.SetRasterizerState(_rasterizerState);

			RenderCommand.SetViewport(_context.SwapChain.BackbufferViewport);

			Renderer2D.BeginScene(cameraController.Camera, .BackToFront);
			
			_alphaBlendState.Bind();

			for(int x < 10)
			for(int y < 10)
			{
				int i = (x + y) % 2;

				Renderer2D.DrawQuad(Vector3(2 * x, 2 * y, 0.5f), Vector2(1.5f, 1), MathHelper.PiOverFour, (i == 0) ? _squareColor0 : _squareColor1);
			}
			
			Renderer2D.DrawQuad(Vector3(0, 0, 1), Vector2(10), 0, _checkerTexture, .White, .(0, 0, 1, 1));

			FontRenderer.DrawText(fonty, "Hallo! gjy", 0, 0, 64, .White, .White);

			Renderer2D.EndScene();
		}

		public override void OnEvent(Event event)
		{
			EventDispatcher dispatcher = EventDispatcher(event);

			dispatcher.Dispatch<ImGuiRenderEvent>(scope (e) => OnImGuiRender(e));

			dispatcher.Dispatch<WindowResizeEvent>(scope (e) => OnWindowResize(e));

			cameraController.OnEvent(event);
		}

		private bool OnImGuiRender(ImGuiRenderEvent e)
		{
			ImGui.Begin("Test");

			ImGui.ColorPicker4("Color", *(float[4]*)&_squareColor0);

			_squareColor1 = ColorRGBA.White - _squareColor0;
			_squareColor1.A = _squareColor0.A;

			ImGui.End();

			_textureViewer.ViewTexture(fonty.[Friend]_atlas);

			_context.SetRenderTarget(null);
			_context.SetDepthStencilTarget(_depthTarget);
			_context.BindRenderTargets();

			return false;
		}

		private bool OnWindowResize(WindowResizeEvent e)
		{
			_depthTarget.ReleaseRef();
			_depthTarget = new DepthStencilTarget(_context.SwapChain.Width, _context.SwapChain.Height);

			return false;
		}
	}
}