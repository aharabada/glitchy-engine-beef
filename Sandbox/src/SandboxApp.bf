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
using System.Collections;
using GlitchyEngine.Content;

namespace Sandbox
{
	class ExampleLayer : Layer
	{
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

			public static readonly VertexElement[] VertexElements ~ delete _;

			public static VertexElement[] IVertexData.VertexElements => VertexElements;

			static this()
			{
				VertexElements = new VertexElement[](
					VertexElement(.R32G32B32_Float, "POSITION"),
					VertexElement(.R8G8B8A8_UNorm,  "COLOR"),
					VertexElement(.R32G32_Float,  "TEXCOORD"),
					);
			}
		}

		GeometryBinding _geometryBinding ~ _?.ReleaseRef();

		GeometryBinding _quadGeometryBinding ~ _?.ReleaseRef();

		RasterizerState _rasterizerState ~ _?.ReleaseRef();
		RasterizerState _rasterizerStateClockWise ~ _?.ReleaseRef();

		GraphicsContext _context ~ _?.ReleaseRef();
		DepthStencilTarget _depthTarget ~ _?.ReleaseRef();

		Texture2D _texture ~ _?.ReleaseRef();
		Texture2D _ge_logo ~ _?.ReleaseRef();

		BlendState _alphaBlendState ~ _?.ReleaseRef();
		BlendState _opaqueBlendState ~ _?.ReleaseRef();

		EffectLibrary _effectLibrary ~ delete _;

		EcsWorld _world = new EcsWorld() ~ delete _;

//		OrthographicCameraController _cameraController ~ delete _;
		PerspectiveCameraController _cameraController ~ delete _;

		private Vector3 CircleCoord(float angle)
		{
			return .(Math.Cos(angle), Math.Sin(angle), 0);
		}

		[AllowAppend]
		public this() : base("Example")
		{
			_context = Application.Get().Window.Context..AddRef();

			_effectLibrary = new EffectLibrary(_context);

			_effectLibrary.LoadNoRefInc("content\\Shaders\\basicShader.hlsl");

			_effectLibrary.LoadNoRefInc("content\\Shaders\\testShader.hlsl");
			
			var textureEffect = _effectLibrary.Load("content\\Shaders\\textureShader.hlsl");

			_depthTarget = new DepthStencilTarget(_context, _context.SwapChain.Width, _context.SwapChain.Height);

			// Create Input Layout

			VertexLayout vertexLayout = new VertexLayout(_context, VertexColorTexture.VertexElements, false, textureEffect.VertexShader);

			textureEffect.ReleaseRef();

			// Create hexagon
			{
				_geometryBinding = new GeometryBinding(_context);
				_geometryBinding.SetPrimitiveTopology(.TriangleList);
				_geometryBinding.SetVertexLayout(vertexLayout);
	
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
	
				let vb = new VertexBuffer(_context, typeof(VertexColorTexture), (.)vertices.Count, .Immutable);
				vb.SetData(vertices);
				_geometryBinding.SetVertexBufferSlot(vb, 0);
				vb.ReleaseRef();
	
				uint16[?] indices = .(
					0, 1, 2,
					0, 2, 3,
					0, 3, 4,
					0, 4, 5,
					0, 5, 6,
					0, 6, 1);
	
				let ib = new IndexBuffer(_context, (.)indices.Count, .Immutable);
				ib.SetData(indices);
				_geometryBinding.SetIndexBuffer(ib);
				ib.ReleaseRef();
			}

			// Create Quad
			{
				_quadGeometryBinding = new GeometryBinding(_context);
				_quadGeometryBinding.SetPrimitiveTopology(.TriangleList);
				_quadGeometryBinding.SetVertexLayout(vertexLayout);
	
				VertexColorTexture[?] vertices = .(
					VertexColorTexture(Vector3(-0.75f, 0.75f, 0), Color.White, .(0, 0)),
					VertexColorTexture(Vector3(-0.75f, -0.75f, 0), Color.White, .(0, 1)),
					VertexColorTexture(Vector3(0.75f, -0.75f, 0), Color.White, .(1, 1)),
					VertexColorTexture(Vector3(0.75f, 0.75f, 0), Color.White, .(1, 0)),
				);
	
				let qvb = new VertexBuffer(_context, typeof(VertexColorTexture), (.)vertices.Count, .Immutable);
				qvb.SetData(vertices);
				_quadGeometryBinding.SetVertexBufferSlot(qvb, 0);
				qvb.ReleaseRef();
	
				uint16[?] indices = .(
					0, 1, 2,
					2, 3, 0);
	
				let qib = new IndexBuffer(_context, (.)indices.Count, .Immutable);
				qib.SetData(indices);
				_quadGeometryBinding.SetIndexBuffer(qib);
				qib.ReleaseRef();
			}

			vertexLayout.ReleaseRef();

			// Create rasterizer state
			RasterizerStateDescription rsDesc = .(.Solid, .Back, true);
			_rasterizerState = new RasterizerState(_context, rsDesc);

			rsDesc.FrontCounterClockwise = false;
			_rasterizerStateClockWise = new RasterizerState(_context, rsDesc);

			_texture = new Texture2D(_context, "content/Textures/Checkerboard.dds");
			_ge_logo = new Texture2D(_context, "content/Textures/GE_Logo.dds");

			let sampler = SamplerStateManager.GetSampler(
				SamplerStateDescription()
				{
					MagFilter = .Point
				});
			
			_texture.SamplerState = sampler;
			_ge_logo.SamplerState = sampler;

			sampler.ReleaseRef();

			BlendStateDescription blendDesc = .();
			blendDesc.RenderTarget[0] = .(true, .SourceAlpha, .InvertedSourceAlpha, .Add, .SourceAlpha, .InvertedSourceAlpha, .Add, .All);
			_alphaBlendState = new BlendState(_context, blendDesc);
			_opaqueBlendState = new BlendState(_context, .Default);

			InitEcs();

			//_cameraController = new OrthographicCameraController(Application.Get().Window.Context.SwapChain.BackbufferViewport.Width /
			//						Application.Get().Window.Context.SwapChain.BackbufferViewport.Height);

			_cameraController = new .(Application.Get().Window.Context.SwapChain.BackbufferViewport.Width /
									Application.Get().Window.Context.SwapChain.BackbufferViewport.Height);
			_cameraController.CameraPosition = .(0, 0, -5);

			TestLoadModel();
		}

		//GeometryBinding _modelTest ~ _?.ReleaseRef();

		List<(Matrix Transform, GeometryBinding Model)> _modelTest = new .() ~ UnloadModelTest!();

		mixin UnloadModelTest()
		{
			for(var entry in _modelTest)
			{
				entry.Model?.ReleaseRef();
			}

			delete _modelTest;
		}

		void TestLoadModel()
		{
			var testEffect = _effectLibrary.Get("testShader");

			ModelLoader.LoadModel("content\\Models\\box.gltf", _context, testEffect, _modelTest);
			
			testEffect.ReleaseRef();

			/*
			CGLTF.Options options = .();
			CGLTF.Data* data;
			CGLTF.Result result = CGLTF.ParseFile(options, "content\\Models\\box.gltf", out data);

			CGLTF.LoadBuffers(options, data, "content\\Models\\box.gltf");

			Log.EngineLogger.Assert(result == .Success, "Failed to load model");

			var mesh = data.Meshes[0];
			var primitive = mesh.Primitives[0];

			var testEffect = _effectLibrary.Get("testShader");

			_modelTest = ModelLoader.PrimitiveToGeoBinding(_context, primitive, testEffect);

			testEffect.ReleaseRef();

			/* TODO make awesome stuff */
			CGLTF.Free(data);
			*/
		}

		void InitEcs()
		{
			_world.Register<TransformComponent>();
			_world.Register<MeshComponent>();
			_world.Register<CameraComponent>();

			for(int x < 20)
			for(int y < 20)
			{
				Entity entity = _world.NewEntity();

				var transform = _world.AssignComponent<TransformComponent>(entity);
				transform.Transform = Matrix.Translation(x * 0.2f, y * 0.2f, 0) * Matrix.Scaling(0.1f);

				var mesh = _world.AssignComponent<MeshComponent>(entity);
				mesh.Mesh = _quadGeometryBinding;
			}
		}

		public override void Update(GameTime gameTime)
		{
			
			_cameraController.Update(gameTime);

			RenderCommand.Clear(null, .(0.2f, 0.2f, 0.2f));
			_depthTarget.Clear(1.0f, 0, .Depth);

			// Draw test geometry
			_context.SetRenderTarget(null);
			_depthTarget.Bind();
			_context.BindRenderTargets();

			_context.SetViewport(_context.SwapChain.BackbufferViewport);

			Renderer.BeginScene(_cameraController.Camera);
			
			_opaqueBlendState.Bind();

			var basicEffect = _effectLibrary.Get("basicShader");
			var textureEffect = _effectLibrary.Get("textureShader");

			// Model test
			{
				_context.SetRasterizerState(_rasterizerStateClockWise);

				var testEffect = _effectLibrary.Get("testShader");
				testEffect.Variables["BaseColor"].SetData(Color.White);
				testEffect.Variables["LightDir"].SetData(Vector3(-1, 1, -0.5f).Normalized());

				for(var entry in _modelTest)
				{
					Renderer.Submit(entry.Model, testEffect, entry.Transform);
				}

				testEffect.ReleaseRef();
			}

			_context.SetRasterizerState(_rasterizerState);

			for(var entity in _world.Enumerate(typeof(TransformComponent)))
			{
				var transform = _world.GetComponent<TransformComponent>(entity);
				transform.Update();
			}

			int i = 0;
			for(var entity in _world.Enumerate(typeof(TransformComponent), typeof(MeshComponent)))
			{
				i++;

				if(i % 2 == 0)
					basicEffect.Variables["BaseColor"].SetData(_squareColor0);
				else
					basicEffect.Variables["BaseColor"].SetData(_squareColor1);

				var transform = _world.GetComponent<TransformComponent>(entity);
				var mesh = _world.GetComponent<MeshComponent>(entity);

				Renderer.Submit(mesh.Mesh, basicEffect, transform.Transform);
			}
			
			basicEffect.Variables["BaseColor"].SetData(_squareColor1);

			_texture.Bind();
			Renderer.Submit(_quadGeometryBinding, textureEffect, .Scaling(1.5f));
			
			_alphaBlendState.Bind();

			_ge_logo.Bind();
			Renderer.Submit(_quadGeometryBinding, textureEffect, .Scaling(1.5f));

			Renderer.EndScene();

			basicEffect.ReleaseRef();
			textureEffect.ReleaseRef();
		}

		ColorRGBA _squareColor0 = ColorRGBA.CornflowerBlue;
		ColorRGBA _squareColor1;

		public override void OnEvent(Event event)
		{
			_cameraController.OnEvent(event);

			EventDispatcher dispatcher = EventDispatcher(event);

			dispatcher.Dispatch<ImGuiRenderEvent>(scope (e) => OnImGuiRender(e));
			dispatcher.Dispatch<WindowResizeEvent>(scope (e) => OnWindowResize(e));
		}

		private bool OnImGuiRender(ImGuiRenderEvent e)
		{
			ImGui.Begin("Test");

			ImGui.ColorEdit3("Square Color", ref _squareColor0);

			_squareColor1 = ColorRGBA.White - _squareColor0;

			ImGui.End();

			return false;
		}

		private bool OnWindowResize(WindowResizeEvent e)
		{
			_depthTarget.ReleaseRef();
			_depthTarget = new DepthStencilTarget(_context, _context.SwapChain.Width, _context.SwapChain.Height);

			return false;
		}
	}

	class SandboxApp : Application
	{
		public this()
		{
			PushLayer(new ExampleLayer());
		}

#if !SANDBOX_2D		
		[Export, LinkName("CreateApplication")]
#endif
		public static Application CreateApplication()
		{
			return new SandboxApp();
		}
	}
}
