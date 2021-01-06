using System;
using GlitchyEngine.Events;
using GlitchyEngine.ImGui;
using GlitchyEngine.Math;
using DirectX.D3D11;
using DirectX.Common;
using DirectX.D3DCompiler;
using System.Diagnostics;
using GlitchyEngine.Renderer;

namespace GlitchyEngine
{
	public class Application
	{
		static Application s_Instance = null;

		private Window _window ~ delete _;
		private bool _running = true;

		private LayerStack _layerStack = new LayerStack() ~ delete _;

		private ImGuiLayer _imGuiLayer;

		private GameTime _gameTime = new GameTime(true) ~ delete _;

		public bool IsRunning => _running;
		public Window Window => _window;

		[Inline]
		public static Application Get() => s_Instance;

		public this()
		{
			Runtime.Assert(s_Instance == null, "Tried to create a second application.");
			s_Instance = this;

			_window = new Window(.Default);
			_window.EventCallback = new => OnEvent;

			_imGuiLayer = new ImGuiLayer();
			PushOverlay(_imGuiLayer);

			MakeTestTriangle();
		}

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

		VertexBuffer _vertexBuffer ~ delete _;
		IndexBuffer _indexBuffer ~ delete _;
		Buffer<ColorRGBA> _cBuffer ~ delete _;

		RasterizerState _rasterizerState ~ delete _;

		VertexLayout _vertexLayout ~ delete _;

		VertexShader _vertexShader ~ delete _;
		PixelShader _pixelShader ~ delete _;

		private Vector3 CircleCoord(float angle)
		{
			return .(Math.Cos(angle), Math.Sin(angle), 0);
		}

		private void MakeTestTriangle()
		{
			_vertexShader = Shader.FromFile!<VertexShader>(_window.Context, "content\\basicShader.hlsl", "VS");

			// Create Input Layout

			_vertexLayout = new VertexLayout(_window.Context, new .(
				VertexElement(.R32G32B32_Float, "POSITION"),
				VertexElement(.R8G8B8A8_UNorm,  "COLOR"),
				), _vertexShader);

			//
			// Load pixel shader
			//

			_pixelShader = Shader.FromFile!<PixelShader>(_window.Context, "content\\basicShader.hlsl", "PS");

			//Todo: _pixelShader.[Friend]_buffers = new .[1];

			_cBuffer = new Buffer<ColorRGBA>(_window.Context, .(0, .Constant, .Immutable, .None));
			_cBuffer.Data = .White;
			_cBuffer.Update();

			_pixelShader.Buffers.ReplaceBuffer("Constants", _cBuffer);

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

			_vertexBuffer = new VertexBuffer(Window.Context, typeof(VertexColor), (.)vertices.Count, .Immutable);//<VertexColor>
			_vertexBuffer.SetData(vertices);

			uint16[?] indices = .(
				0, 1, 2,
				0, 2, 3,
				0, 3, 4,
				0, 4, 5,
				0, 5, 6,
				0, 6, 1);

			_indexBuffer = new IndexBuffer(Window.Context, (.)indices.Count, .Immutable);
			_indexBuffer.SetData(indices);

			// Create rasterizer state
			GlitchyEngine.Renderer.RasterizerStateDescription rsDesc = .(.Solid, .Back, true);
			_rasterizerState = new RasterizerState(Window.Context, rsDesc);
		}

		public void OnEvent(Event e)
		{
			EventDispatcher dispatcher = scope .(e);
			dispatcher.Dispatch<WindowCloseEvent>(scope => OnWindowClose);

			for(Layer layer in _layerStack)
			{
				layer.OnEvent(e);
				if(e.Handled)
					break;
			}
		}

		public void Run()
		{
			while(_running)
			{
				_gameTime.NewFrame();

				Input.NewFrame();

				_window.Context.ClearRenderTarget(null, .(0.2f, 0.2f, 0.2f));

				// Draw test geometry
				{
					_window.Context.SetRenderTarget(null);
					_window.Context.BindRenderTargets();

					_window.Context.SetVertexBuffer(0, _vertexBuffer);
					_window.Context.SetIndexBuffer(_indexBuffer);

					_window.Context.SetVertexLayout(_vertexLayout);

					_window.Context.SetPrimitiveTopology(.TriangleList);

					_window.Context.SetVertexShader(_vertexShader);

					_window.Context.SetRasterizerState(_rasterizerState);

					_window.Context.SetViewport(Window.Context.SwapChain.BackbufferViewport);

					_window.Context.SetPixelShader(_pixelShader);

					_window.Context.DrawIndexed(3 * 6);
				}

				for(Layer layer in _layerStack)
					layer.Update(_gameTime);
				
				_window.Update();

				_imGuiLayer.ImGuiRender();

				_window.Context.SwapChain.Present();
			}
		}

		public void PushLayer(Layer ownLayer) => _layerStack.PushLayer(ownLayer);

		public void PushOverlay(Layer ownOverlay) => _layerStack.PushOverlay(ownOverlay);

		public bool OnWindowClose(WindowCloseEvent e)
		{
			_running = false;
			return true;
		}
	}
}
