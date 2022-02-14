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
using System.Collections;
using System.Diagnostics;

namespace Sandbox
{
	class GameLayer : Layer
	{
		GraphicsContext _context ~ _?.ReleaseRef();

		BlendState _alphaBlendState ~ _?.ReleaseRef();

		Font _font ~ _.ReleaseRef();

		DepthStencilState _depthStencilState ~ _.ReleaseRef();

		Rocket _rocket ~ delete _;

		OrthographicCamera _camera ~ delete _;

		List<Obstacle> _obstacles = new List<Obstacle>() ~ DeleteContainerAndItems!(_);

		FontRenderer.PreparedText pressSpaceToStart ~ _.ReleaseRef();
		FontRenderer.PreparedText pressSpaceToRestart ~ _.ReleaseRef();

		ColorHSV worldColor = .(0, 0.5f, 1.0f);

		[AllowAppend]
		public this() : base("Example")
		{
			Application.Get().Window.IsVSync = false;

			_context = Application.Get().Window.Context..AddRef();

			BlendStateDescription blendDesc = .();
			blendDesc.RenderTarget[0] = .(true, .SourceAlpha, .InvertedSourceAlpha, .Add, .SourceAlpha, .InvertedSourceAlpha, .Add, .All);
			_alphaBlendState = new BlendState(blendDesc);

			_font = new Font("C:\\Windows\\Fonts\\arial.ttf", 64, true, 'A', 16);

			_camera = new .()
				{
					NearPlane = -10,
					FarPlane = 10,
					Height = 5,
					Width = 5 * _context.SwapChain.AspectRatio
				}..Update();

			DepthStencilStateDescription dssDesc = .()
				{
					DepthEnabled = false
				};
			_depthStencilState = new DepthStencilState(dssDesc);

			pressSpaceToStart = FontRenderer.PrepareText(_font, "Press [SPACE]", 1);

			pressSpaceToRestart = FontRenderer.PrepareText(_font, "YOU DIED!\nPress [SPACE] to restart", 0.5f);

			InitGame();
		}

		private void InitGame()
		{
			_rocket = new Rocket();
			_rocket.Obstacles = _obstacles;

			InitStarField();
		}

		Vector4[] points = new Vector4[1000] ~ delete _;

		Random startRandom = new .() ~ delete _;

		private void InitStarField()
		{
			for (int i < points.Count)
			{
				Vector4 v = .();
				v.X = startRandom.Next(-1000, 1000) / 2000f * _camera.Width;
				v.Y = startRandom.Next(-1000, 1000) / 2000f * _camera.Height;
				v.Z = startRandom.Next(0, 1000) / 2000.0f;
				v.W = startRandom.Next(1000, 3000) / 1000.0f;

				points[i] = v;
			}
		}

		private float lastObstacle = 0.0f;

		public override void Update(GameTime gameTime)
		{ 
			worldColor.H += gameTime.DeltaTime * 18 * _rocket.FlightSpeed;
 			worldColor.H %= 360.0f;

			ColorRGBA wColor = .((ColorRGB)worldColor, 1.0f);

			float screenWidth = _camera.Width;
			Obstacle.ScreenWidth = screenWidth / 2.0f;

			lastObstacle += Obstacle.Speed * gameTime.DeltaTime;
			
			if (lastObstacle <= -Obstacle.ScreenWidth)
			{
				_obstacles.Add(new Obstacle());
				lastObstacle += 2.5f;
				_obstacles.Back.Position.X = Obstacle.ScreenWidth + 1.0f;
				_obstacles.Back.Position.Y = Obstacle.random.Next(-1000, 1000) / 1000f;
			}

			for (int i < _obstacles.Count)
			{
				_obstacles[i].Update(gameTime);

				if (_obstacles[i].Dead)
				{
					delete _obstacles[i];

					_obstacles.RemoveAt(i);
					i--;
				}
			}

			_rocket.Update(gameTime);
			Obstacle.Speed = -_rocket.FlightSpeed;

			RenderCommand.Clear(null, .Black);
			
			// Draw test geometry
			RenderCommand.SetRenderTarget(null);
			RenderCommand.BindRenderTargets();

			RenderCommand.SetViewport(_context.SwapChain.BackbufferViewport);

			RenderCommand.SetBlendState(_alphaBlendState);
			RenderCommand.SetDepthStencilState(_depthStencilState);
			
			Renderer2D.BeginScene(_camera, .BackToFront);
			
			DrawStartField(gameTime);
			
			Renderer2D.EndScene();
			
			Renderer2D.BeginScene(_camera, .BackToFront);

			Renderer2D.DrawQuad(Vector3(0, 2.75f, 1), Vector2(screenWidth, 1), 0, wColor);

			Renderer2D.DrawQuad(Vector3(0, -2.75f, 1), Vector2(screenWidth, 1), 0, wColor);
			
			for (Obstacle obs in _obstacles)
			{
				obs.Draw(wColor);
			}

			_rocket.Draw();

			var scorePrep = FontRenderer.PrepareText(_font, scope $"{_rocket.Score}", 1.0f);

			FontRenderer.DrawText(scorePrep, -scorePrep.AdvanceX / 2, 1.5f, .Black);
			FontRenderer.DrawText(scorePrep, -scorePrep.AdvanceX / 2 + 0.1f, 1.6f, .(230, 230, 230));

			scorePrep.ReleaseRef();

			if (!_rocket.Started)
			{
				float f = (float)Math.Cos(gameTime.TotalTime.TotalSeconds) * 0.5f + 0.55f;

				FontRenderer.DrawText(pressSpaceToStart, -pressSpaceToStart.AdvanceX / 2f, 0, .(1, 0, 0, f));
			}

			if (_rocket.Dead)
			{
				float f = (float)Math.Cos(gameTime.TotalTime.TotalSeconds) * 0.5f + 0.55f;

				FontRenderer.DrawText(pressSpaceToRestart, -pressSpaceToRestart.AdvanceX / 2f, 0, .(1, 0, 0, f));
			}

			Renderer2D.EndScene();
		}

		private void DrawStartField(GameTime gameTime)
		{
			for (int i < points.Count)
			{
				points[i].X -= _rocket.FlightSpeed * gameTime.DeltaTime * points[i].Z;

				if (points[i].X < _camera.Left)
				{
					points[i].X = _camera.Right + startRandom.Next(500, 1500) / 1000.0f;
				}

				Renderer2D.DrawCircle(Vector3(points[i].XY, 5), .(0.01f * points[i].W), Color.White);
			}
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
			_camera.Width = _camera.Height * e.Width / (float)e.Height;
			_camera.Update();

			return false;
		}
	}
}