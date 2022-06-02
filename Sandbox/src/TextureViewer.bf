using GlitchyEngine.Renderer;
using GlitchyEngine;
using ImGui;
using GlitchyEngine.Math;
using System;
namespace Sandbox
{
	class TextureViewer
	{
		enum BackgroundMode : int32
		{
			White,
			Black,
			Checkerboard
		}

		enum SampleMode : int32
		{
			Point,
			Linear
		}

		GraphicsContext _context ~ _.ReleaseRef();

		Effect _effect ~ _.ReleaseRef();

		float _zoom = 1.0f;
		
		BackgroundMode _backgroundMode = .Checkerboard;

		SampleMode _sampleMode = .Linear;

		RenderTarget2D _target ~ _?.ReleaseRef();
		// TODO: we don't need depth!
		DepthStencilTarget _depth ~ _?.ReleaseRef();

		SamplerState _samplerPoint ~ _.ReleaseRef();
		SamplerState _samplerLinear ~ _.ReleaseRef();

		public this()
		{
			_context = Renderer.[Friend]_context..AddRef();

			InitEffect();
			InitState();
			// TODO: rasterizerstate and depthstencilstate
		}

		private void InitEffect()
		{
			_effect = new Effect("content\\Shaders\\textureViewerShader.hlsl");
		}

		private void InitState()
		{
			SamplerStateDescription desc = .();
			desc.MagFilter = .Linear;
			desc.MinFilter = .Linear;
			_samplerLinear = SamplerStateManager.GetSampler(desc);
			
			desc.MagFilter = .Point;
			desc.MinFilter = .Point;
			_samplerPoint = SamplerStateManager.GetSampler(desc);
		}

		Vector2 _position;

		bool _moving;

		float _colorOffset = 0;
		float _colorScale = 1;
		float _alphaOffset = 0;
		float _alphaScale = 1;

		public void ViewTexture(Texture2D viewedTexture)
		{
			ImGui.Begin("Texture Viewer");

			ImGui.SliderFloat("Zoom", &_zoom, 0.01f, 100.0f);

			char8*[] items = scope .("White", "Black", "Checkerboard");

			ImGui.Combo("Background", (.)&_backgroundMode, items.Ptr, (.)items.Count);
			
			items = scope .("Point", "Linear");

			ImGui.Combo("Sampler", (.)&_sampleMode, items.Ptr, (.)items.Count);

			ImGui.SliderFloat2("Color offset and scale", *(float[2]*)&_colorOffset, -1.0f, 1.0f);
			ImGui.SliderFloat2("Alpha offset and scale", *(float[2]*)&_alphaOffset, -1.0f, 1.0f);

			ImGui.SliderFloat2("Position", *(float[2]*)&_position, 2 * -Math.Max(viewedTexture.Width, viewedTexture.Height) * _zoom, 2 * Math.Max(viewedTexture.Width, viewedTexture.Height) * _zoom);

			ImGui.BeginChild("imageChild");

			UpdateInput();

			var viewportSize = ImGui.GetContentRegionAvail();

			viewportSize.x = Math.Max(viewportSize.x, 1);
			viewportSize.y = Math.Max(viewportSize.y, 1);

			if(_target == null || viewportSize.x != _target.Width || viewportSize.y != _target.Height)
			{
				_target?.ReleaseRef();
				_target = new RenderTarget2D(.(.R8G8B8A8_UNorm, (.)viewportSize.x, (.)viewportSize.y));
				_depth?.ReleaseRef();
				_depth = new DepthStencilTarget((.)viewportSize.x, (.)viewportSize.y, .D16_UNorm);
			}

			RenderTexture(viewedTexture);

			ImGui.Image(_target, viewportSize);

			ImGui.EndChild();

			ImGui.End();
		}

		float lastWheel;

		private void UpdateInput()
		{
			var windowPos = ImGui.GetWindowPos();
			var mousePos = ImGui.GetIO().MousePos;
			Vector2 mouseInWindow = .(mousePos.x - windowPos.x, mousePos.y - windowPos.y);

			bool windowHovered = ImGui.IsWindowHovered();

			if(windowHovered && Input.IsMouseButtonPressing(.MiddleButton))
			{
				_moving = true;
			}
			else if(Input.IsMouseButtonReleased(.MiddleButton))
			{
				_moving = false;
			}

			if(windowHovered || _moving)
			{
				float mouseWheel = ImGui.GetIO().MouseWheel;

				float delta = mouseWheel - lastWheel;

				if(delta != 0)
				{
					_position -= mouseInWindow;
					_position /= _zoom;

					_zoom *= Math.Pow(1.1f, delta);
					
					_position *= _zoom;
					_position += mouseInWindow;
				}

			}

			if(_moving)
			{
				Int2 movement = Input.GetMouseMovement();

				_position.X += movement.X;
				_position.Y += movement.Y;
			}
		}

		OrthographicCamera _camera = new OrthographicCamera() ~ delete _;

		private void RenderTexture(Texture2D viewedTexture)
		{
			Viewport vp = .(0, 0, _target.Width, _target.Height);
			RenderCommand.SetViewport(vp);

			// TODO: don't clear pink!
			RenderCommand.Clear(_target, .Pink);
			RenderCommand.Clear(_depth, .Depth, 1.0f, 0);

			//_target.Bind();
			_context.SetRenderTarget(_target);
			_context.SetDepthStencilTarget(_depth);
			_context.BindRenderTargets();

			Vector2 textureSize = Vector2(viewedTexture.Width, viewedTexture.Height);
			Vector2 zoomedTextureSize = textureSize * _zoom;
			
			Vector2 targetSize = Vector2(_target.Width, _target.Height);

			_effect.Variables["ColorOffset"].SetData(_colorOffset);
			_effect.Variables["ColorScale"].SetData(_colorScale);
			_effect.Variables["AlphaOffset"].SetData(_alphaOffset);
			_effect.Variables["AlphaScale"].SetData(_alphaScale);

			_camera.Left = 0;
			_camera.Top = 0;
			_camera.Right = targetSize.X;
			_camera.Bottom = -targetSize.Y;
			_camera.NearPlane = -5;
			_camera.FarPlane = 5;
			_camera.Update();

			Renderer2D.BeginScene(_camera);
			
			switch(_backgroundMode)
			{
			case .Black:
				Renderer2D.DrawQuadPivotCorner(Vector3(0, 0, 1), targetSize, 0, .Black);
			case .White:
				Renderer2D.DrawQuadPivotCorner(Vector3(0, 0, 1), targetSize, 0, .White);
			case .Checkerboard:
				float quadSize = 50.0f;

				Vector2 numQuads = (targetSize / 500f) * 10f;

				for(float x = 0; x < numQuads.X; x++)
				{
					for(float y = 0; y < numQuads.Y; y++)
					{
						Renderer2D.DrawQuadPivotCorner(Vector3(x * quadSize, -y * quadSize, 1), quadSize.XX, 0, ((x + y) % 2 == 0) ? .White : .Gray);
					}
				}
				break;
			}

			Renderer2D.EndScene();

			var sampler = viewedTexture.SamplerState;

			switch(_sampleMode)
			{
			case .Point:
				viewedTexture.SamplerState = _samplerPoint;
			case .Linear:
				viewedTexture.SamplerState = _samplerLinear;
			}

			Renderer2D.BeginScene(_camera, .SortByTexture, _effect);

			Renderer2D.DrawQuadPivotCorner(Vector3(_position * .(1, -1), 0), zoomedTextureSize, 0, viewedTexture);
			
			Renderer2D.EndScene();

			viewedTexture.SamplerState = sampler;
		}
	}
}
