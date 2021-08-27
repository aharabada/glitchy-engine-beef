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
using GlitchyEngine.Renderer.Animation;

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
		
		Material _checkerMaterial ~ _?.ReleaseRef();
		Material _logoMaterial ~ _?.ReleaseRef();
		Texture2D _texture ~ _?.ReleaseRef();
		Texture2D _ge_logo ~ _?.ReleaseRef();

		BlendState _alphaBlendState ~ _?.ReleaseRef();
		BlendState _opaqueBlendState ~ _?.ReleaseRef();

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

			var effectLibrary = Application.Get().EffectLibrary;

			effectLibrary.LoadNoRefInc("content\\Shaders\\basicShader.hlsl");

			effectLibrary.LoadNoRefInc("content\\Shaders\\testShader.hlsl");
			
			var textureEffect = effectLibrary.Load("content\\Shaders\\textureShader.hlsl");

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

			_logoMaterial = new Material(textureEffect);
			_logoMaterial.SetTexture("ColorTexture", _ge_logo);

			_checkerMaterial = new Material(textureEffect);
			_checkerMaterial.SetTexture("ColorTexture", _texture);

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
			_cameraController.TranslationSpeed = 10;

			TestLoadModel();
		}

		//GeometryBinding _modelTest ~ _?.ReleaseRef();

		List<(Matrix Transform, GeometryBinding Model)> _modelTest = new .() ~ UnloadModelTest!();

		Skeleton Skeleton ~ delete _;
		AnimationClip Clip ~ delete _;
		AnimationPlayer AnimationPlayer ~ delete _;

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
			var testEffect = Application.Get().EffectLibrary.Get("testShader");

			//ModelLoader.LoadModel("content\\Models\\Test\\axisTest.glb", _context, testEffect, _modelTest, out Skeleton, out Clip);
			//ModelLoader.LoadModel("content\\Models\\RiggedSimple\\RiggedSimple.glb", _context, testEffect, _modelTest, out Skeleton, out Clip);
			//ModelLoader.LoadModel("content\\Models\\Fox\\Fox_2.glb", _context, testEffect, _modelTest, out Skeleton, out Clip);
			//ModelLoader.LoadModel("content\\Models\\DancingCylinder\\DancingCylinder.glb", _context, testEffect, _modelTest, out Skeleton, out Clip);
			//ModelLoader.LoadModel("content\\Models\\Figure\\Figure.gltf", _context, testEffect, _modelTest, out Skeleton, out Clip);
			ModelLoader.LoadModel("content\\Models\\RiggedFigure\\RiggedFigure.glb", _context, testEffect, _modelTest, out Skeleton, out Clip);

			testEffect.ReleaseRef();

			if(Skeleton != null && Clip != null)
				AnimationPlayer = new AnimationPlayer(Skeleton, Clip);

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

		float f = 0.0f;

		bool playAnimation = false;
		bool drawModel = false;

		public override void Update(GameTime gameTime)
		{
			f += (float)gameTime.FrameTime.TotalSeconds;

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

			var basicEffect = Application.Get().EffectLibrary.Get("basicShader");
			
			// Model test
			{
				//AnimationPlayer.CurrentClip.Samples[0].JointPose[1].Rotation = .(1, 0, 0, 1)..Normalize();

				Matrix scaling = .Scaling(1f, 1.0f, -1.0f);

				var testEffect = Application.Get().EffectLibrary.Get("testShader");

				if(AnimationPlayer != null)
				{
					if(playAnimation)
						AnimationPlayer.Update(gameTime);
					else
					{
						GameTime gt = new GameTime();
						AnimationPlayer.Update(gt);
						delete gt;
					}

					//_context.SetRasterizerState(_rasterizerStateClockWise);

					int i = 0;
					for(var globalPose in AnimationPlayer.Pose.GlobalPose)
					{
						Joint currentJoint = AnimationPlayer.Skeleton.Joints[i];

						Matrix bindPose = currentJoint.InverseBindPose.Invert();

						// Draw skeleton
						Matrix mat = AnimationPlayer.SkinningMatricies[i] * bindPose;

						uint8 parentId = currentJoint.ParentID;

						if(parentId != uint8.MaxValue)
						{
							Vector3 start = mat.Translation;

							Joint parent = AnimationPlayer.Skeleton.Joints[parentId];

							Matrix parentBindPose = parent.InverseBindPose.Invert();

							Matrix parentMatrix = AnimationPlayer.SkinningMatricies[parentId] * parentBindPose;

							Vector3 end = parentMatrix.Translation;

							Renderer.DrawLine(start, end, .Black, scaling);
						}

						Renderer.DrawLine(.Zero, Vector3(0.1f, 0, 0), .Red,  scaling * mat);
						Renderer.DrawLine(.Zero, Vector3(0, 0.1f, 0), .Lime, scaling * mat);
						Renderer.DrawLine(.Zero, Vector3(0, 0, 0.1f), .Blue, scaling * mat);

						i++;
					}
	
					testEffect.Variables["SkinningMatrices"].SetData(AnimationPlayer.SkinningMatricies);
					testEffect.Variables["InvTransSkinningMatrices"].SetData(AnimationPlayer.InvTransSkinningMatricies);
	
					testEffect.Variables["BaseColor"].SetData(Color.White);
					testEffect.Variables["LightDir"].SetData(Vector3(1, 1, -0.5f).Normalized());
	
				}

				if(drawModel)
				{
					for(var entry in _modelTest)
					{
						Renderer.Submit(entry.Model, testEffect, .Identity * scaling);//entry.Transform
					}
				}

				/*
				// Draw bind pose
				for(Joint joint in Skeleton.Joints)
				{
					Matrix bindPose = joint.InverseBindPose.Invert();

					if(joint.ParentID != uint8.MaxValue)
					{
						Vector3 start = bindPose.Translation;

						Matrix parentBindPose = Skeleton.Joints[joint.ParentID].InverseBindPose.Invert();

						Vector3 end = parentBindPose.Translation;

						Renderer.DrawLine(start, end, .White);
					}

					Renderer.DrawLine(.Zero, Vector3(0.1f, 0, 0), .Red, bindPose);
					Renderer.DrawLine(.Zero, Vector3(0, 0.1f, 0), .Lime, bindPose);
					Renderer.DrawLine(.Zero, Vector3(0, 0, 0.1f), .Blue, bindPose);
				}
				*/
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
			
			_checkerMaterial.SetVariable("BaseColor", Color.White);

			Renderer.Submit(_quadGeometryBinding, _checkerMaterial, Matrix.RotationZ(f) * .Scaling(1.5f));
			
			_alphaBlendState.Bind();
			
			_logoMaterial.SetVariable("BaseColor", Color.Pink);

			Renderer.Submit(_quadGeometryBinding, _logoMaterial, .Translation(0, 0, -1) * .Scaling(2f));

			Renderer.EndScene();

			basicEffect.ReleaseRef();
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
			ImGui.Begin("Animation");

			if(AnimationPlayer != null)
			{
				ImGui.DragFloat("Timestamp", &AnimationPlayer.TimeStamp, 0.01f, -Clip.Duration, Clip.Duration);
	
				while(AnimationPlayer.TimeStamp < 0)
				{
					AnimationPlayer.TimeStamp += Clip.Duration;
				}
	
				ImGui.Checkbox("Play", &playAnimation);
			}

			ImGui.Checkbox("Draw Model", &drawModel);

			ImGui.End();

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
