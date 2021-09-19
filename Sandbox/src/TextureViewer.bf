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

		Renderer2D _renderer;

		float _zoom = 1.0f;
		
		BackgroundMode _backgroundMode = .Checkerboard;

		SampleMode _sampleMode = .Linear;

		RenderTarget2D _target ~ _?.ReleaseRef();
		// TODO: we don't need depth!
		DepthStencilTarget _depth ~ _?.ReleaseRef();

		SamplerState _samplerPoint ~ _.ReleaseRef();
		SamplerState _samplerLinear ~ _.ReleaseRef();

		public this(GraphicsContext context, Renderer2D renderer2D, EffectLibrary effectLibrary = null)
		{
			Log.EngineLogger.AssertDebug(context != null);

			_context = context;
			_renderer = renderer2D;

			InitEffect(effectLibrary);
			InitState();
			// TODO: rasterizerstate and depthstencilstate
		}

		private void InitEffect(EffectLibrary effectLibrary)
		{
			var effectLibrary;

			if(effectLibrary == null)
			{
				effectLibrary = new EffectLibrary(_context);
				defer:: delete effectLibrary;
			}

			_effect = effectLibrary.Load("content\\Shaders\\textureViewerShader.hlsl");
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

			if(_target == null || viewportSize.x != _target.Width || viewportSize.y != _target.Height)
			{
				_target?.ReleaseRef();
				_target = new RenderTarget2D(_context, (.)viewportSize.x, (.)viewportSize.y, .R8G8B8A8_UNorm);
				_depth?.ReleaseRef();
				_depth = new DepthStencilTarget(_context, (.)viewportSize.x, (.)viewportSize.y, .D16_UNorm);
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
				Point movement = Input.GetMouseMovement();

				_position.X += movement.X;
				_position.Y += movement.Y;
			}
		}

		private void RenderTexture(Texture2D viewedTexture)
		{
			Viewport vp = .(0, 0, _target.Width, _target.Height);
			_context.SetViewport(vp);

			// TODO: don't clear pink!
			_context.ClearRenderTarget(_target, .Pink);
			_depth.Clear(1.0f, 0, .Depth);

			//_target.Bind();
			_context.SetRenderTarget(_target);
			_depth.Bind();
			_context.BindRenderTargets();

			Vector2 textureSize = Vector2(viewedTexture.Width, viewedTexture.Height);
			Vector2 zoomedTextureSize = textureSize * _zoom;
			
			Vector2 targetSize = Vector2(_target.Width, _target.Height);

			_effect.Variables["ColorOffset"].SetData(_colorOffset);
			_effect.Variables["ColorScale"].SetData(_colorScale);
			_effect.Variables["AlphaOffset"].SetData(_alphaOffset);
			_effect.Variables["AlphaScale"].SetData(_alphaScale);

			_renderer.Begin(.SortByTexture, targetSize);

			switch(_backgroundMode)
			{
			case .Black:
				_renderer.Draw(null, 0, 0, targetSize.X, targetSize.Y, .Black, 1);
			case .White:
				_renderer.Draw(null, 0, 0, targetSize.X, targetSize.Y, .White, 1);
			case .Checkerboard:
				float quadSize = 50.0f;
	
				for(int x = 0; x < (targetSize.X / 500f) * 10f; x++)
				{
					for(int y = 0; y < (targetSize.Y / 500f) * 10f; y++)
					{
						_renderer.Draw(null, x * quadSize, y * quadSize, quadSize, quadSize, ((x + y) % 2 == 0) ? .White : .Gray, 1);
					}
				}
				break;
			}

			_renderer.End();

			var sampler = viewedTexture.SamplerState;

			switch(_sampleMode)
			{
			case .Point:
				viewedTexture.SamplerState = _samplerPoint;
			case .Linear:
				viewedTexture.SamplerState = _samplerLinear;
			}

			_renderer.Begin(.SortByTexture, targetSize, 100, _effect);

			_renderer.Draw(viewedTexture, _position.X, _position.Y, zoomedTextureSize.X, zoomedTextureSize.Y);
			
			_renderer.End();

			viewedTexture.SamplerState = sampler;
		}
	}
}
