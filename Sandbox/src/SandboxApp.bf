using System;
using GlitchyEngine;
using GlitchyEngine.Events;
using System.Diagnostics;
using GlitchLog;
using GlitchyEngine.ImGui;
using ImGui;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;

namespace Sandbox
{
	class ExampleLayer : Layer
	{
		private OrthographicCamera _camera ~ delete _; // PerspectiveCamera

		[Ordered]
		struct VertexColorTexture : IVertexData
		{
			public Vector3 Position;
			public Color Color;
			public Vector2 TexCoord;

			public this() => this = default;

			public this(Vector3 pos, Color color)
			{
				Position = pos;
				Color = color;
				TexCoord = .();
			}
			
			public this(Vector3 pos, Color color, Vector2 texCoord)
			{
				Position = pos;
				Color = color;
				TexCoord = texCoord;
			}

			//public static readonly InputElementDescription[] InputLayout ~ delete _;
			
			public static readonly VertexLayout VertexLayout ~ delete _;

			public static VertexLayout IVertexData.VertexLayout => VertexLayout;

			static this()
			{
				//VertexLayout = new VertexLayout();
			}
		}

		VertexLayout _vertexLayout ~ delete _;

		GeometryBinding _geometryBinding ~ delete _;
		VertexBuffer _vertexBuffer ~ _?.ReleaseRef();
		IndexBuffer _indexBuffer ~ _?.ReleaseRef();

		GeometryBinding _quadGeometryBinding ~ delete _;
		VertexBuffer _quadVertexBuffer ~ _?.ReleaseRef();
		IndexBuffer _quadIndexBuffer ~ _?.ReleaseRef();

		RasterizerState _rasterizerState ~ delete _;

		Effect _effect ~ _?.ReleaseRef();
		Effect _textureEffect ~ _?.ReleaseRef();

		ConstantBuffer _cBuffer ~ _?.ReleaseRef();

		GraphicsContext _context ~ _?.ReleaseRef();

		Texture2D _texture ~ _?.ReleaseRef();

		private Vector3 CircleCoord(float angle)
		{
			return .(Math.Cos(angle), Math.Sin(angle), 0);
		}

		[AllowAppend]
		public this() : base("Example")
		{
			_context = Application.Get().Window.Context..AddRef();

			{
				_effect = new Effect();

				let vs = Shader.FromFile!<VertexShader>(_context, "content\\basicShader.hlsl", "VS");
				_effect.VertexShader = vs;
				vs.ReleaseRef();

				let ps = Shader.FromFile!<PixelShader>(_context, "content\\basicShader.hlsl", "PS");
				_effect.PixelShader = ps;
				ps.ReleaseRef();
			}

			{
				_textureEffect = new Effect();

				let vs = Shader.FromFile!<VertexShader>(_context, "content\\textureShader.hlsl", "VS");
				_textureEffect.VertexShader = vs;
				vs.ReleaseRef();

				let ps = Shader.FromFile!<PixelShader>(_context, "content\\textureShader.hlsl", "PS");
				_textureEffect.PixelShader = ps;
				ps.ReleaseRef();
			}

			// Create Input Layout

			_vertexLayout = new VertexLayout(_context, new .(
				VertexElement(.R32G32B32_Float, "POSITION"),
				VertexElement(.R8G8B8A8_UNorm,  "COLOR"),
				VertexElement(.R32G32_Float,  "TEXCOORD"),
				), _textureEffect.VertexShader);


			_cBuffer = _effect.PixelShader.Buffers["Constants"] as ConstantBuffer;
			_cBuffer.AddRef();

			// Create hexagon
			{
				_geometryBinding = new GeometryBinding(_context);
				_geometryBinding.SetPrimitiveTopology(.TriangleList);
				_geometryBinding.SetVertexLayout(_vertexLayout);
	
				float pO3 = Math.PI_f / 3.0f;
				VertexColorTexture[?] vertices = .(
					VertexColorTexture(.Zero, Color(255,255,255)),
					VertexColorTexture(CircleCoord(0), Color(255,  0,  0)),
					VertexColorTexture(CircleCoord(pO3), Color(255,255,  0)),
					VertexColorTexture(CircleCoord(pO3*2), Color(  0,255,  0)),
					VertexColorTexture(CircleCoord(Math.PI_f), Color(  0,255,255)),
					VertexColorTexture(CircleCoord(-pO3*2), Color(  0,  0,255)),
					VertexColorTexture(CircleCoord(-pO3), Color(255,  0,255)),
				);
	
				_vertexBuffer = new VertexBuffer(_context, typeof(VertexColorTexture), (.)vertices.Count, .Immutable);
				_vertexBuffer.SetData(vertices);
				_geometryBinding.SetVertexBufferSlot(_vertexBuffer, 0);
	
				uint16[?] indices = .(
					0, 1, 2,
					0, 2, 3,
					0, 3, 4,
					0, 4, 5,
					0, 5, 6,
					0, 6, 1);
	
				_indexBuffer = new IndexBuffer(_context, (.)indices.Count, .Immutable);
				_indexBuffer.SetData(indices);
				_geometryBinding.SetIndexBuffer(_indexBuffer);
			}

			// Create Quad
			{
				_quadGeometryBinding = new GeometryBinding(_context);
				_quadGeometryBinding.SetPrimitiveTopology(.TriangleList);
				_quadGeometryBinding.SetVertexLayout(_vertexLayout);
	
				VertexColorTexture[?] vertices = .(
					VertexColorTexture(Vector3(-0.75f, 0.75f, 0), Color.White, .(0, 0)),
					VertexColorTexture(Vector3(-0.75f, -0.75f, 0), Color.White, .(0, 1)),
					VertexColorTexture(Vector3(0.75f, -0.75f, 0), Color.White, .(1, 1)),
					VertexColorTexture(Vector3(0.75f, 0.75f, 0), Color.White, .(1, 0)),
				);
	
				_quadVertexBuffer = new VertexBuffer(_context, typeof(VertexColorTexture), (.)vertices.Count, .Immutable);
				_quadVertexBuffer.SetData(vertices);
				_quadGeometryBinding.SetVertexBufferSlot(_quadVertexBuffer, 0);
	
				uint16[?] indices = .(
					0, 1, 2,
					2, 3, 0);
	
				_quadIndexBuffer = new IndexBuffer(_context, (.)indices.Count, .Immutable);
				_quadIndexBuffer.SetData(indices);
				_quadGeometryBinding.SetIndexBuffer(_quadIndexBuffer);
			}

			// Create rasterizer state
			GlitchyEngine.Renderer.RasterizerStateDescription rsDesc = .(.Solid, .Back, true);
			_rasterizerState = new RasterizerState(_context, rsDesc);

			// Camera
			_camera = new OrthographicCamera();
			_camera.NearPlane = -1;
			_camera.FarPlane = 1;
			/*
			_camera = new PerspectiveCamera();
			_camera.NearPlane = 0.1f;
			_camera.FarPlane = 10.0f;
			_camera.FovY = Math.PI_f / 4;
			_camera.Position = .(0, -1, -5);
			*/

			_texture = new Texture2D(_context, "content/Textures/Checkerboard.dds");

			let sampler = new SamplerState(_context,
				SamplerStateDescription()
				{
					MagFilter = .Point
				});
			
			_texture.SamplerState = sampler;
			sampler.ReleaseRef();
		}

		public override void Update(GameTime gameTime)
		{
			Vector2 movement = .();

			if(Input.IsKeyPressed(Key.W))
			{
				movement.Y += 1;
			}
			if(Input.IsKeyPressed(Key.S))
			{
				movement.Y -= 1;
			}
			
			if(Input.IsKeyPressed(Key.A))
			{
				movement.X -= 1;
			}
			if(Input.IsKeyPressed(Key.D))
			{
				movement.X += 1;
			}

			if(movement != .Zero)
				movement.Normalize();

			movement *= (float)(gameTime.FrameTime.TotalSeconds);

			_camera.Position += .(movement, 0);

			_camera.Width = _context.SwapChain.BackbufferViewport.Width / 256;
			_camera.Height = _context.SwapChain.BackbufferViewport.Height / 256;

			//_camera.AspectRatio = Application.Get().Window.Context.SwapChain.BackbufferViewport.Width /
			//						Application.Get().Window.Context.SwapChain.BackbufferViewport.Height;

			_camera.Update();

			RenderCommand.Clear(null, .(0.2f, 0.2f, 0.2f));

			// Draw test geometry
			_context.SetRenderTarget(null);
			_context.BindRenderTargets();

			_context.SetRasterizerState(_rasterizerState);

			_context.SetViewport(_context.SwapChain.BackbufferViewport);

			Renderer.BeginScene(_camera);

			for(int x < 20)
			for(int y < 20)
			{
				if((x + y) % 2 == 0)
					_cBuffer["BaseColor"].SetData(_squareColor0);
				else
					_cBuffer["BaseColor"].SetData(_squareColor1);

				_cBuffer.Update();

				Matrix transform = Matrix.Translation(x * 0.2f, y * 0.2f, 0) * Matrix.Scaling(0.1f);
				Renderer.Submit(_quadGeometryBinding, _effect, transform);
			}
			
			_cBuffer["BaseColor"].SetData(ColorRGBA.White);
			_cBuffer.Update();
			
			_texture.Bind();

			Renderer.Submit(_geometryBinding, _effect);
			Renderer.Submit(_quadGeometryBinding, _textureEffect, .Scaling(1.5f));

			Renderer.EndScene();
		}

		ColorRGBA _squareColor0 = ColorRGBA.CornflowerBlue;
		ColorRGBA _squareColor1;

		public override void OnEvent(Event event)
		{
			EventDispatcher dispatcher = scope EventDispatcher(event);

			dispatcher.Dispatch<ImGuiRenderEvent>(scope (e) => OnImGuiRender(e));
		}

		private bool OnImGuiRender(ImGuiRenderEvent e)
		{
			ImGui.Begin("Test");

			ImGui.ColorEdit3("Square Color", ref _squareColor0);

			_squareColor1 = ColorRGBA.White - _squareColor0;

			ImGui.End();

			return false;
		}
	}

	class SandboxApp : Application
	{
		public this()
		{
			PushLayer(new ExampleLayer());
		}

		[Export, LinkName("CreateApplication")]
		public static Application CreateApplication()
		{
			return new SandboxApp();
		}
	}
}
