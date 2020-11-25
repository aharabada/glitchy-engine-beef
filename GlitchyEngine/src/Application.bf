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

		VertexBuffer<VertexColor> _vertexBuffer ~ delete _;
		IndexBuffer _indexBuffer ~ delete _;

		RasterizerState _rasterizerState ~ delete _;

		ID3D11VertexShader* _vertexShader ~ _?.Release();
		ID3D11PixelShader* _pixelShader ~ _?.Release();
		ID3D11InputLayout* _inputLayout ~ _?.Release();

		private Vector3 CircleCoord(float angle)
		{
			return .(Math.Cos(angle), Math.Sin(angle), 0);
		}

		private void MakeTestTriangle()
		{
			// Compile vertex shader
			ID3DBlob* vsCode = null;
			ID3DBlob* errorBlob = null;
			var result = D3DCompiler.D3DCompileFromFile("content\\basicShader.hlsl".ToScopedNativeWChar!(), null, .StandardInclude, "VS", "vs_5_0", .Debug, .None, &vsCode, &errorBlob);

			if(result.Failed || errorBlob != null)
			{
				Debug.Write("ERROR: Failed to compile Vertex Shader: {}", result);
				//ErrorPrinter.PrintErrorBlob(errorBlob);
				Runtime.FatalError("Failed to compile Vertex Shader");
			}

			result = Window.Context.[Friend]nativeDevice.CreateVertexShader(vsCode.GetBufferPointer(), vsCode.GetBufferSize(), null, &_vertexShader);

			if(result.Failed)
			{
				Debug.Write("ERROR: Failed to create Vertex Shader: {}", result);
				Runtime.FatalError("Failed to create Vertex Shader");
			}

			// Create Input Layout

			InputElementDescription[2] elementDescs = .(
				InputElementDescription("POSITION", 0, .R32G32B32_Float, 0),
				InputElementDescription("COLOR",    0, .R8G8B8A8_UNorm,  0)
			);

			result = Window.Context.[Friend]nativeDevice.CreateInputLayout(&elementDescs, (.)elementDescs.Count, vsCode.GetBufferPointer(), vsCode.GetBufferSize(), &_inputLayout);

			vsCode.Release();

			if(result.Failed)
			{
				Debug.Write("ERROR: Failed to create input layout: {}", result);
				Runtime.FatalError("Failed to create input layout");
			}

			//
			// Load pixel shader
			//

			ID3DBlob* psCode = null;

			result = D3DCompiler.D3DCompileFromFile("content\\basicShader.hlsl".ToScopedNativeWChar!(), null, .StandardInclude, "PS", "ps_5_0", .Debug, .None, &psCode, &errorBlob);

			if(result.Failed || errorBlob != null)
			{
				Debug.Write("ERROR: Failed to compile Pixel Shader: {}", result);
				//ErrorPrinter.PrintErrorBlob(errorBlob);
				Runtime.FatalError("Failed to compile Pixel Shader");
			}

			result = Window.Context.[Friend]nativeDevice.CreatePixelShader(psCode.GetBufferPointer(), psCode.GetBufferSize(), null, &_pixelShader);

			psCode.Release();

			if(result.Failed)
			{
				Debug.Write("ERROR: Failed to create Pixel Shader: {}", result);
				Runtime.FatalError("Failed to create Pixel Shader");
			}

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

			_vertexBuffer = new VertexBuffer<VertexColor>(Window.Context, (.)vertices.Count, .Immutable);
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

			if(result.Failed)
			{
				Debug.Write("ERROR: Failed to create Vertex Buffer: {}", result);
				Runtime.FatalError();
			}

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

				for(Layer layer in _layerStack)
					layer.Update(_gameTime);
				
				_window.Update();
				
				_window.Context.SetRenderTarget(null);
				_window.Context.BindRenderTargets();
				
				Window.Context.SetVertexBuffer(0, _vertexBuffer);
				Window.Context.SetIndexBuffer(_indexBuffer);

				var _immediateContext = Window.Context.[Friend]nativeContext;

				_immediateContext.InputAssembler.SetInputLayout(_inputLayout);
				_immediateContext.InputAssembler.SetPrimitiveTopology(.TriangleList);

				_immediateContext.VertexShader.SetShader(_vertexShader, null, 0);

				Window.Context.SetRasterizerState(_rasterizerState);

				Window.Context.SetViewport(Window.Context.SwapChain.BackbufferViewport);

				_immediateContext.PixelShader.SetShader(_pixelShader, null, 0);

				Window.Context.DrawIndexed(3 * 6);

				_imGuiLayer.ImGuiRender();

				Window.Context.SwapChain.Present();
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
