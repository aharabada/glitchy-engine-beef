/*using GlitchyEngine.Renderer;
using GlitchyEngine.Events;
using GlitchyEngine.ImGui;
using GlitchyEngine.Math;
using GlitchyEngine;
using System;
using GlitchyEngine.World;
using GlitchyEngine.Renderer.Animation;
using GlitchyEngine.Content;
using System.Collections;

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
			AssetHandle _texture;
			AssetHandle _ge_logo;

			BlendState _alphaBlendState ~ _?.ReleaseRef();
			BlendState _opaqueBlendState ~ _?.ReleaseRef();

			EcsWorld _world = new EcsWorld() ~ delete _;

			PerspectiveCameraController _cameraController ~ delete _;

			private Vector3 CircleCoord(float angle)
			{
				return .(Math.Cos(angle), Math.Sin(angle), 0);
			}

			[AllowAppend]
			public this() : base("Example")
			{
				Application.Get().Window.IsVSync = false;

				_context = Application.Get().Window.Context..AddRef();

				//var effectLibrary = Application.Get().EffectLibrary;

				//effectLibrary.LoadNoRefInc("content\\Shaders\\basicShader.hlsl");

				//effectLibrary.LoadNoRefInc("content\\Shaders\\testShader.hlsl");
				
				Effect textureEffect = Content.GetAsset<Effect>(Content.LoadAsset("Shaders\\textureShader.hlsl"));

				_depthTarget = new DepthStencilTarget(_context.SwapChain.Width, _context.SwapChain.Height);

				// Create Input Layout

				VertexLayout vertexLayout = new VertexLayout(VertexColorTexture.VertexElements, false);

				//textureEffect.ReleaseRef();

				// Create hexagon
				{
					_geometryBinding = new GeometryBinding();
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
		
					let vb = new VertexBuffer(typeof(VertexColorTexture), (.)vertices.Count, .Immutable);
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
		
					let ib = new IndexBuffer((.)indices.Count, .Immutable);
					ib.SetData(indices);
					_geometryBinding.SetIndexBuffer(ib);
					ib.ReleaseRef();
				}

				// Create Quad
				{
					_quadGeometryBinding = new GeometryBinding();
					_quadGeometryBinding.SetPrimitiveTopology(.TriangleList);
					_quadGeometryBinding.SetVertexLayout(vertexLayout);
		
					VertexColorTexture[?] vertices = .(
						VertexColorTexture(Vector3(-0.75f, 0.75f, 0), Color.White, .(0, 0)),
						VertexColorTexture(Vector3(-0.75f, -0.75f, 0), Color.White, .(0, 1)),
						VertexColorTexture(Vector3(0.75f, -0.75f, 0), Color.White, .(1, 1)),
						VertexColorTexture(Vector3(0.75f, 0.75f, 0), Color.White, .(1, 0)),
					);
		
					let qvb = new VertexBuffer(typeof(VertexColorTexture), (.)vertices.Count, .Immutable);
					qvb.SetData(vertices);
					_quadGeometryBinding.SetVertexBufferSlot(qvb, 0);
					qvb.ReleaseRef();
		
					uint16[?] indices = .(
						0, 1, 2,
						2, 3, 0);
		
					let qib = new IndexBuffer((.)indices.Count, .Immutable);
					qib.SetData(indices);
					_quadGeometryBinding.SetIndexBuffer(qib);
					qib.ReleaseRef();
				}

				vertexLayout.ReleaseRef();

				// Create rasterizer state
				RasterizerStateDescription rsDesc = .(.Solid, .Back, true);
				_rasterizerState = new RasterizerState(rsDesc);

				rsDesc.FrontCounterClockwise = false;
				_rasterizerStateClockWise = new RasterizerState(rsDesc);

				_texture = Content.LoadAsset("content/Textures/Checkerboard.dds");//new Texture2D("content/Textures/Checkerboard.dds");
				_ge_logo = Content.LoadAsset("content/Textures/GE_Logo.dds");//new Texture2D("content/Textures/GE_Logo.dds");

				Texture2D texture = Content.GetAsset<Texture2D>(_texture);
				Texture2D ge_logo = Content.GetAsset<Texture2D>(_ge_logo);

				let sampler = SamplerStateManager.GetSampler(
					SamplerStateDescription()
					{
						MagFilter = .Point
					});
				
				texture.SamplerState = sampler;
				ge_logo.SamplerState = sampler;

				sampler.ReleaseRef();

				_logoMaterial = new Material(textureEffect);
				_logoMaterial.SetTexture("ColorTexture", _ge_logo);

				_checkerMaterial = new Material(textureEffect);
				_checkerMaterial.SetTexture("ColorTexture", _texture);

				BlendStateDescription blendDesc = .();
				blendDesc.RenderTarget[0] = .(true, .SourceAlpha, .InvertedSourceAlpha, .Add, .SourceAlpha, .InvertedSourceAlpha, .Add, .All);
				_alphaBlendState = new BlendState(blendDesc);
				_opaqueBlendState = new BlendState(.Default);

				InitEcs();

				_cameraController = new .(_context.SwapChain.AspectRatio);
				_cameraController.CameraPosition = .(0, 0, -5);
				_cameraController.TranslationSpeed = 10;

				TestLoadModel();
			}

			List<AnimationClip> Clips = new List<AnimationClip>() ~ DeleteContainerAndReleaseItems!(_);

			Material animationMat;

			void TestLoadModel()
			{
				Effect testEffect = Content.LoadAsset<Effect>("Shaders\\testShader.hlsl");//Application.Get().EffectLibrary.Get("testShader");
				var materialTestMaterial = new Material(testEffect);
				animationMat = materialTestMaterial;

				Matrix[] matrices = scope Matrix[255];
				Matrix3x3[] matrices2 = scope Matrix3x3[255];

				for(int i < 255)
				{
					matrices[i] = .Identity;
					matrices2[i] = .Identity;
				}

				materialTestMaterial.SetVariable("SkinningMatrices", matrices);
				materialTestMaterial.SetVariable("InvTransSkinningMatrices", matrices2);

				materialTestMaterial.SetVariable("BaseColor", Color.White);
				materialTestMaterial.SetVariable("LightDir", Vector3(1, 1, -0.5f).Normalized());

				ModelLoader.LoadModel("content\\Models\\RiggedFigure\\RiggedFigure.glb", materialTestMaterial, _world, Clips);

				materialTestMaterial.ReleaseRef();
				testEffect.ReleaseRef();

				for(var (entity, transform, mesh, meshRenderer) in _world.Enumerate<TransformComponent, MeshComponent, SkinnedMeshRendererComponent>())
				{
					var animation = _world.AssignComponent<AnimationComponent>(entity);

					animation.AnimationClip = Clips[0];
					animation.TimeScale = 1.0f;
					animation.IsPlaying = true;
					animation.[Friend]_pose = new SkeletonPose(meshRenderer.Skeleton);
				}
			}

			EcsEntity evenCrazierParent;
			EcsEntity crazyParent;

			Material testMaterial1 ~ _?.ReleaseRef();
			Material testMaterial2 ~ _?.ReleaseRef();

			void InitEcs()
			{
				_world.Register<DebugNameComponent>();
				_world.Register<TransformComponent>();
				_world.Register<ParentComponent>();
				_world.Register<MeshComponent>();
				_world.Register<MeshRendererComponent>();
				_world.Register<SkinnedMeshRendererComponent>();
				_world.Register<CameraComponent>();
				_world.Register<AnimationComponent>();
				
				Effect basicEffect = Content.LoadAsset<Effect>("Shaders\\basicShader.hlsl");//Application.Get().EffectLibrary.Get("basicShader");

				testMaterial1 = new Material(basicEffect);
				testMaterial1.SetVariable("BaseColor", _squareColor0);
				testMaterial2 = new Material(basicEffect);
				testMaterial2.SetVariable("BaseColor", _squareColor1);

				basicEffect.ReleaseRef();
				/*
				Entity[20][20] entities;

				int i = 0;

				for(int x < 20)
				for(int y < 20)
				{
					Entity entity = _world.NewEntity();

					entities[x][y] = entity;

					var transform = _world.AssignComponent<TransformComponent>(entity);
					*transform = TransformComponent();
					transform.LocalTransform = Matrix.Translation(x * 0.2f, y * 0.2f, 0) * Matrix.Scaling(0.1f);

					var mesh = _world.AssignComponent<MeshComponent>(entity);
					mesh.Mesh = _quadGeometryBinding;
					
					i++;

					var meshRenderer = _world.AssignComponent<MeshRendererComponent>(entity);

					if(i % 2 == 0)
						meshRenderer.Material = testMaterial1;
					else
						meshRenderer.Material = testMaterial2;
				}
				
				crazyParent = _world.NewEntity();
				evenCrazierParent = _world.NewEntity();

				var crazyTransform = _world.AssignComponent<TransformComponent>(evenCrazierParent);
				crazyTransform.Position = .Zero;
				crazyTransform.Scale = .One;
				crazyTransform.Rotation = .Identity;

				var pp = _world.AssignComponent<ParentComponent>(crazyParent);
				pp.Entity = evenCrazierParent;

				crazyTransform = _world.AssignComponent<TransformComponent>(crazyParent);
				crazyTransform.Position = .Zero;
				crazyTransform.Scale = .(2.0f, 2.0f, 2.0f);
				crazyTransform.Rotation = .Identity;

				for(int x < 20)
				for(int y < 20)
				{
					var parent = _world.AssignComponent<ParentComponent>(entities[x][y]);
					parent.Entity = crazyParent;
				}
				*/
			}

			float f = 0.0f;

			bool playAnimation = false;

			public override void Update(GameTime gameTime)
			{
				f += (float)gameTime.FrameTime.TotalSeconds;

				_cameraController.Update(gameTime);

				RenderCommand.Clear(null, .(0.2f, 0.2f, 0.2f));
				RenderCommand.Clear(_depthTarget, .Depth, 1.0f, 0);

				// Draw test geometry
				RenderCommand.SetRenderTarget(null);
				RenderCommand.SetDepthStencilTarget(_depthTarget);
				RenderCommand.BindRenderTargets();

				RenderCommand.SetViewport(_context.SwapChain.BackbufferViewport);

				Renderer.BeginScene(_cameraController.Camera);
				
				RenderCommand.SetBlendState(_opaqueBlendState);

				Effect basicEffect = Content.LoadAsset<Effect>("Shaders\\basicShader.hlsl");//Application.Get().EffectLibrary.Get("basicShader");

				RenderCommand.SetRasterizerState(_rasterizerState);
				
				TransformSystem.Update(_world);
				
				for(var (entity, transform, mesh, meshRenderer) in _world.Enumerate<TransformComponent, MeshComponent, MeshRendererComponent>())
				{
					Renderer.Submit(mesh.Mesh, meshRenderer.Material, transform.WorldTransform);
				}
				
				for(var (entity, transform, mesh, meshRenderer, animation) in _world.Enumerate<TransformComponent, MeshComponent, SkinnedMeshRendererComponent, AnimationComponent>())
				{
					var material = meshRenderer.Material;

					var timeIndex = ref animation.TimeIndex;
					var currentClip = animation.AnimationClip;
					var pose = animation.Pose;

					// Only advance time index if animation is playing
					if(animation.IsPlaying)
					{
						timeIndex += (float)gameTime.FrameTime.TotalSeconds * animation.TimeScale;
						
						if(currentClip.IsLooping && currentClip.Duration != 0)
						{
							timeIndex %= currentClip.Duration;

							// modulo can result in negative numbers
							if(timeIndex < 0)
								timeIndex += currentClip.Duration;
						}
					}

					var skeleton = currentClip.Skeleton;

					// Update joints
					for(int i < skeleton.Joints.Count)
					{
						ref JointPose localPose = ref pose.LocalPose[i];

						localPose = currentClip.JointAnimations[i].GetCurrentPose(timeIndex);

						Matrix jointToParent =
							Matrix.Translation(localPose.Translation) *
							Matrix.RotationQuaternion(localPose.Rotation) *
							Matrix.Scaling(localPose.Scale);

						uint8 parentIndex = skeleton.Joints[i].ParentID;
						
						ref Matrix globalPose = ref pose.GlobalPose[i];

						if(parentIndex == uint8.MaxValue)
						{
							globalPose = jointToParent;
						}
						else
						{
							globalPose = pose.GlobalPose[parentIndex] * jointToParent;
						}

						pose.SkinningMatricies[i] = globalPose * skeleton.Joints[i].InverseBindPose;
						pose.InvTransSkinningMatricies[i] = ((Matrix3x3)pose.SkinningMatricies[i]).Inverse().Transpose();
					}
					
					int i = 0;
					for(var globalPose in pose.GlobalPose)
					{
						Joint currentJoint = meshRenderer.Skeleton.Joints[i];

						Matrix bindPose = currentJoint.InverseBindPose.Invert();

						// Draw skeleton
						Matrix mat = pose.SkinningMatricies[i] * bindPose;

						uint8 parentId = currentJoint.ParentID;

						if(parentId != uint8.MaxValue)
						{
							Vector3 start = mat.Translation;

							Joint parent = meshRenderer.Skeleton.Joints[parentId];

							Matrix parentBindPose = parent.InverseBindPose.Invert();

							Matrix parentMatrix = pose.SkinningMatricies[parentId] * parentBindPose;

							Vector3 end = parentMatrix.Translation;

							Renderer.DrawLine(start, end, .Black, transform.WorldTransform);
						}

						DebugRenderer.DrawCoordinateCross(transform.WorldTransform * mat, 0.5f);

						i++;
					}
					
					material.SetVariable("SkinningMatrices", pose.SkinningMatricies);
					material.SetVariable("InvTransSkinningMatrices", pose.InvTransSkinningMatricies);

					// non engine
					material.SetVariable("BaseColor", Color.White);
					material.SetVariable("LightDir", Vector3(1, 1, -0.5f).Normalized());

					Renderer.Submit(mesh.Mesh, material, transform.WorldTransform);
				}
				
				basicEffect.Variables["BaseColor"].SetData(_squareColor1);
				
				_checkerMaterial.SetVariable("BaseColor", Color.White);

				Renderer.Submit(_quadGeometryBinding, _checkerMaterial, Matrix.RotationY(f) * Matrix.RotationX(MathHelper.PiOverTwo) * .Scaling(1.5f));

				RenderCommand.SetBlendState(_alphaBlendState);
				
				_logoMaterial.SetVariable("BaseColor", Color.Pink);

				Renderer.Submit(_quadGeometryBinding, _logoMaterial, .Translation(0, 0, -1) * .Scaling(2f));

				DebugRenderer.Render(_world);

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
				/*
				ImGui.Begin("Test");

				var v = ImGui.ColorEdit3("Square Color", ref _squareColor0);

				if(v)
				{
					testMaterial1.SetVariable("BaseColor", _squareColor0);
					testMaterial2.SetVariable("BaseColor", ColorRGBA.White - _squareColor0);
				}

				ImGui.End();
				*/
				return false;
			}

			private bool OnWindowResize(WindowResizeEvent e)
			{
				_depthTarget.ReleaseRef();
				_depthTarget = new DepthStencilTarget(_context.SwapChain.Width, _context.SwapChain.Height);

				return false;
			}
		}

}*/