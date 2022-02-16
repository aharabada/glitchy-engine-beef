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
		GraphicsContext _context ~ _?.ReleaseRef();
		DepthStencilTarget _depthTarget ~ _?.ReleaseRef();

		Texture2D _checkerTexture ~ _?.ReleaseRef();

		BlendState _alphaBlendState ~ _?.ReleaseRef();

		TextureViewer _textureViewer ~ delete _;
		
		OrthographicCameraController cameraController ~ delete _;

		Font fonty ~ _.ReleaseRef();
		
		ColorRGBA _squareColor0 = ColorRGBA.CornflowerBlue;
		ColorRGBA _squareColor1;

		DepthStencilState _depthStencilState ~ _.ReleaseRef();

		[AllowAppend]
		public this() : base("Example")
		{
			Application.Get().Window.IsVSync = false;

			_context = Application.Get().Window.Context..AddRef();

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
			var cascadiaCode = new Font("C:\\Windows\\Fonts\\CascadiaCode.ttf", 64, true, 'A', 1);
			fonty.Fallback = japanese..ReleaseRefNoDelete();
			japanese.Fallback = emojis..ReleaseRefNoDelete();
			emojis.Fallback = mathstuff..ReleaseRefNoDelete();
			mathstuff.Fallback = cascadiaCode..ReleaseRefNoDelete();

			_textureViewer = new TextureViewer();

			cameraController = new OrthographicCameraController(_context.SwapChain.AspectRatio);

			DepthStencilStateDescription dssDesc = .()
				{
					DepthEnabled = false
				};
			_depthStencilState = new DepthStencilState(dssDesc);
		}

		String text = new .() ~ delete _;

		public override void Update(GameTime gameTime)
		{
			cameraController.Update(gameTime);

			RenderCommand.Clear(null, .(0.2f, 0.2f, 0.2f));
			RenderCommand.Clear(_depthTarget, .Depth, 1.0f, 0);
			
			// Draw test geometry
			RenderCommand.SetRenderTarget(null);
			RenderCommand.SetDepthStencilTarget(_depthTarget);
			RenderCommand.BindRenderTargets();

			RenderCommand.SetViewport(_context.SwapChain.BackbufferViewport);

			Renderer2D.Stats.Reset();

			Renderer2D.BeginScene(cameraController.Camera, .BackToFront);

			RenderCommand.SetBlendState(_alphaBlendState);
			RenderCommand.SetDepthStencilState(_depthStencilState);

			float rotation = (float)gameTime.TotalTime.TotalSeconds;

			Renderer2D.DrawQuad(Vector3(0, 0, 1), Vector2(20), 0, _checkerTexture, .White, .(0, 0, 10, 10));
			
			Renderer2D.DrawCircle(Vector3(0, 0, 0f), Vector2(5), rotation, _checkerTexture, .LightBlue, innerRadius, .(0, 0, 1, 1));
			
			Renderer2D.DrawQuad(Vector3(0, -7, 1), Vector2(2), -rotation, _checkerTexture, .White, .(0, 0, 10, 10));

			Renderer2D.DrawCircle(Vector3(-2, -2, -2f), Vector2(1), .GreenYellow);

			Renderer2D.EndScene();
			Renderer2D.BeginScene(cameraController.Camera, .BackToFront);
			
			for(float x = -5.0f; x < 5.0f; x += 0.1f)
			for(float y = -5.0f; y < 5.0f; y += 0.1f)
			{
				ColorRGBA color = .((x + 5.0f) / 10.0f, 0.4f, (y + 5.0f) / 10.0f, 0.6f);
				Renderer2D.DrawQuad(Vector3(x, y, 0.75f), Vector2(0.098f), 0, color);
			}
			
			for(int x < 10)
			for(int y < 10)
			{
				int i = (x + y) % 2;

				Renderer2D.DrawQuad(Vector3(2 * x, 2 * y, 0.5f), Vector2(1.5f, 1), MathHelper.PiOverFour, (i == 0) ? _squareColor0 : _squareColor1);
			}

			var prepared = FontRenderer.PrepareText(fonty, text, 64, .White, .White);
			FontRenderer.DrawText(prepared, 0, 0);
			prepared.ReleaseRef();

			Renderer2D.EndScene();
		}

		float innerRadius = 0.5f;

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

			ImGui.DragFloat("Inner Radius", &innerRadius, 0.01f);

			ImGui.ColorPicker4("Color", *(float[4]*)&_squareColor0);

			_squareColor1 = ColorRGBA.White - _squareColor0;
			_squareColor1.A = _squareColor0.A;

			ImGui.End();

			ImGui.Begin("Renderer2D Stats:");

			ImGui.Text($"Quad Drawcalls: {Renderer2D.Stats.QuadDrawCalls}");
			ImGui.Text($"Circle Drawcalls: {Renderer2D.Stats.CircleDrawCalls}");
			ImGui.Text($"Total Drawcalls: {Renderer2D.Stats.TotalDrawCalls}");

			ImGui.Text($"Quads: {Renderer2D.Stats.QuadCount}");
			ImGui.Text($"Circles: {Renderer2D.Stats.CircleCount}");

			ImGui.Text($"Vertices: {Renderer2D.Stats.TotalVertexCount}");
			ImGui.Text($"Indices: {Renderer2D.Stats.TotalIndexCount}");
			
			ImGui.End();

			//_textureViewer.ViewTexture(fonty.Fallback.Fallback.Fallback.Fallback.[Friend]_atlas);
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