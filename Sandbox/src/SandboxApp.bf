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
		private OrthographicCamera _camera ~ delete _;
		
		struct VertexColor : IVertexData
		{
			public Vector3 Position;
			public Color Color;

			public this() => this = default;

			public this(Vector3 pos, Color color)
			{
				Position = pos;
				Color = color;
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
		VertexBuffer _vertexBuffer ~ delete _;
		IndexBuffer _indexBuffer ~ delete _;

		GeometryBinding _quadGeometryBinding ~ delete _;
		VertexBuffer _quadVertexBuffer ~ delete _;
		IndexBuffer _quadIndexBuffer ~ delete _;

		RasterizerState _rasterizerState ~ delete _;

		Effect _effect ~ delete _;
		VertexShader _vertexShader ~ delete _;
		PixelShader _pixelShader ~ delete _;

		Buffer<ColorRGBA> _cBuffer ~ delete _;

		private Vector3 CircleCoord(float angle)
		{
			return .(Math.Cos(angle), Math.Sin(angle), 0);
		}

		[AllowAppend]
		public this() : base("Example")
		{
			{
				_effect = new Effect();

				_vertexShader = Shader.FromFile!<VertexShader>(Application.Get().Window.Context, "content\\basicShader.hlsl", "VS");
				_effect.VertexShader = _vertexShader;

				_pixelShader = Shader.FromFile!<PixelShader>(Application.Get().Window.Context, "content\\basicShader.hlsl", "PS");
				_effect.PixelShader = _pixelShader;
			}

			// Create Input Layout

			_vertexLayout = new VertexLayout(Application.Get().Window.Context, new .(
				VertexElement(.R32G32B32_Float, "POSITION"),
				VertexElement(.R8G8B8A8_UNorm,  "COLOR"),
				), _vertexShader);

			_cBuffer = new Buffer<ColorRGBA>(Application.Get().Window.Context, .(0, .Constant, .Immutable));
			_cBuffer.Data = .White;
			_cBuffer.Update();

			_pixelShader.Buffers.ReplaceBuffer("Constants", _cBuffer);

			// Create hexagon
			{
				_geometryBinding = new GeometryBinding(Application.Get().Window.Context);
				_geometryBinding.SetPrimitiveTopology(.TriangleList);
				_geometryBinding.SetVertexLayout(_vertexLayout);
	
				float pO3 = Math.PI_f / 3.0f;
				VertexColor[?] vertices = .(
					VertexColor(.Zero, Color(255,255,255)),
					VertexColor(CircleCoord(0), Color(255,  0,  0)),
					VertexColor(CircleCoord(pO3), Color(255,255,  0)),
					VertexColor(CircleCoord(pO3*2), Color(  0,255,  0)),
					VertexColor(CircleCoord(Math.PI_f), Color(  0,255,255)),
					VertexColor(CircleCoord(-pO3*2), Color(  0,  0,255)),
					VertexColor(CircleCoord(-pO3), Color(255,  0,255)),
				);
	
				_vertexBuffer = new VertexBuffer(Application.Get().Window.Context, typeof(VertexColor), (.)vertices.Count, .Immutable);
				_vertexBuffer.SetData(vertices);
				_geometryBinding.SetVertexBufferSlot(_vertexBuffer, 0);
	
				uint16[?] indices = .(
					0, 1, 2,
					0, 2, 3,
					0, 3, 4,
					0, 4, 5,
					0, 5, 6,
					0, 6, 1);
	
				_indexBuffer = new IndexBuffer(Application.Get().Window.Context, (.)indices.Count, .Immutable);
				_indexBuffer.SetData(indices);
				_geometryBinding.SetIndexBuffer(_indexBuffer);
			}

			// Create Quad
			{
				_quadGeometryBinding = new GeometryBinding(Application.Get().Window.Context);
				_quadGeometryBinding.SetPrimitiveTopology(.TriangleList);
				_quadGeometryBinding.SetVertexLayout(_vertexLayout);
	
				VertexColor[?] vertices = .(
					VertexColor(Vector3(-0.75f, 0.75f, 0), Color.Blue),
					VertexColor(Vector3(-0.75f, -0.75f, 0), Color.Blue),
					VertexColor(Vector3(0.75f, -0.75f, 0), Color.Blue),
					VertexColor(Vector3(0.75f, 0.75f, 0), Color.Blue),
				);
	
				_quadVertexBuffer = new VertexBuffer(Application.Get().Window.Context, typeof(VertexColor), (.)vertices.Count, .Immutable);
				_quadVertexBuffer.SetData(vertices);
				_quadGeometryBinding.SetVertexBufferSlot(_quadVertexBuffer, 0);
	
				uint16[?] indices = .(
					0, 1, 2,
					2, 3, 0);
	
				_quadIndexBuffer = new IndexBuffer(Application.Get().Window.Context, (.)indices.Count, .Immutable);
				_quadIndexBuffer.SetData(indices);
				_quadGeometryBinding.SetIndexBuffer(_quadIndexBuffer);
			}

			// Create rasterizer state
			GlitchyEngine.Renderer.RasterizerStateDescription rsDesc = .(.Solid, .Back, true);
			_rasterizerState = new RasterizerState(Application.Get().Window.Context, rsDesc);

			// Camera
			_camera = new OrthographicCamera();
			_camera.NearPlane = -1;
			_camera.FarPlane = 1;
		}

		public override void Update(GameTime gameTime)
		{
			_camera.Width = Application.Get().Window.Context.SwapChain.BackbufferViewport.Width / 256;
			_camera.Height = Application.Get().Window.Context.SwapChain.BackbufferViewport.Height / 256;

			_camera.Update();

			RenderCommand.Clear(null, .(0.2f, 0.2f, 0.2f));

			// Draw test geometry
			Application.Get().Window.Context.SetRenderTarget(null);
			Application.Get().Window.Context.BindRenderTargets();

			Application.Get().Window.Context.SetRasterizerState(_rasterizerState);

			Application.Get().Window.Context.SetViewport(Application.Get().Window.Context.SwapChain.BackbufferViewport);

			RenderCommand.SetViewport(Application.Get().Window.Context.SwapChain.BackbufferViewport);

			Renderer.BeginScene(_camera);

			Renderer.Submit(_geometryBinding, _effect);
			Renderer.Submit(_quadGeometryBinding, _effect);

			Renderer.EndScene();

		}

		public override void OnEvent(Event event)
		{
			Log.ClientLogger.Trace($"{event}");

			EventDispatcher dispatcher = scope EventDispatcher(event);

			dispatcher.Dispatch<ImGuiRenderEvent>(scope (e) => OnImGuiRender(e));
		}

		private bool OnImGuiRender(ImGuiRenderEvent e)
		{
			ImGui.Begin("Test");

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
