using System;
using GlitchyEngine;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using ImGui;
using GlitchyEngine.ImGui;
using GlitchyEngine.Events;
using System.Diagnostics;
using System.Collections;

namespace Sandbox.VoxelFun
{
	public class VoxelTestLayer : Layer
	{
		private PerspectiveCamera _camera ~ delete _;

		[Ordered]
		public struct VertexColorTexture : IVertexData
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

		VertexLayout _vertexLayout ~ delete _;

		GeometryBinding _cubeGeo ~ _?.ReleaseRef();

		GeometryBinding _geometryBinding ~ _?.ReleaseRef();

		GeometryBinding _quadGeometryBinding ~ _?.ReleaseRef();

		GeometryBinding _lineGeometryBinding ~ _?.ReleaseRef();

		RasterizerState _rasterizerState ~ delete _;

		Effect _effect ~ _?.ReleaseRef();
		Effect _textureEffect ~ _?.ReleaseRef();

		GraphicsContext _context ~ _?.ReleaseRef();

		Texture2D _texture ~ _?.ReleaseRef();
		Texture2D _ge_logo ~ _?.ReleaseRef();

		BlendState _alphaBlendState ~ _?.ReleaseRef();
		BlendState _opaqueBlendState ~ _?.ReleaseRef();

		DepthStencilTarget _depthStencilTarget ~ _?.ReleaseRef();

		World _world ~ delete _;

		private Vector3 CircleCoord(float angle)
		{
			return .(Math.Cos(angle), Math.Sin(angle), 0);
		}

		[AllowAppend]
		public this() : base("VoxelTest")
		{
			_context = Application.Get().Window.Context..AddRef();

			_depthStencilTarget = new DepthStencilTarget(_context, _context.SwapChain.Width, _context.SwapChain.Height);

			_effect = new Effect(_context, "content\\Shaders\\basicShader.hlsl");
			
			_textureEffect = new Effect(_context, "content\\Shaders\\textureShader.hlsl");

			// Create Input Layout

			_vertexLayout = new VertexLayout(_context, VertexColorTexture.VertexElements, _textureEffect.VertexShader);
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
				_quadGeometryBinding.SetVertexLayout(_vertexLayout);

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

			// Create Cube
			{
				_cubeGeo = new GeometryBinding(_context);
				_cubeGeo.SetPrimitiveTopology(.TriangleList);
				_cubeGeo.SetVertexLayout(_vertexLayout);

				List<VertexColorTexture> vertices = new List<VertexColorTexture>();
				defer delete vertices;
				List<uint32> indices = new List<uint32>();
				defer delete indices;

				uint32 i = 0;

				VoxelGeometryGenerator.GenerateBlockModel(0, .Zero, .All, vertices, indices, ref i);

				let qvb = new VertexBuffer(_context, typeof(VertexColorTexture), (.)vertices.Count, .Immutable);
				qvb.SetData<VertexColorTexture>(vertices);
				_cubeGeo.SetVertexBufferSlot(qvb, 0);
				qvb.ReleaseRef();

				let qib = new IndexBuffer(_context, (.)indices.Count, .Immutable, .None, .Index32Bit);
				qib.SetData<uint32>(indices);
				_cubeGeo.SetIndexBuffer(qib);
				qib.ReleaseRef();
			}
			
			// Create Line
			{
				_lineGeometryBinding = new GeometryBinding(_context);
				_lineGeometryBinding.SetPrimitiveTopology(.LineList);
				_lineGeometryBinding.SetVertexLayout(_vertexLayout);

				VertexColorTexture[?] vertices = .(
					VertexColorTexture(Vector3(0, 0, 0), Color.White, .(0, 0)),
					VertexColorTexture(Vector3(0, 0, 10), Color.White, .(0, 1)),
				);

				let qvb = new VertexBuffer(_context, typeof(VertexColorTexture), (.)vertices.Count, .Immutable);
				qvb.SetData(vertices);
				_lineGeometryBinding.SetVertexBufferSlot(qvb, 0);
				qvb.ReleaseRef();

				uint16[?] indices = .(0, 1);

				let qib = new IndexBuffer(_context, (.)indices.Count, .Immutable);
				qib.SetData(indices);
				_lineGeometryBinding.SetIndexBuffer(qib);
				qib.ReleaseRef();
			}

			// Create rasterizer state
			GlitchyEngine.Renderer.RasterizerStateDescription rsDesc = .(.Solid, .Back, true);
			rsDesc.DepthClipEnabled = true;
			_rasterizerState = new RasterizerState(_context, rsDesc);

			// Camera
			_camera = new PerspectiveCamera();
			_camera.NearPlane = 0.1f;
			_camera.FarPlane = 1000.0f;
			_camera.FovY = Math.PI_f / 4;
			_camera.Position = .(0, 128, 0);//-320

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

			_world = new World();
			if(World.CreateWorld("test", 1337, _world) case .Err(.WorldAlreadyExists))
			{
				World.LoadWorld("test", _world);
			}

			_world.ChunkManager = new ChunkManager(_context, _vertexLayout, _world);
			_world.ChunkManager.Texture = _texture..AddRef();
			_world.ChunkManager.TextureEffect = _textureEffect..AddRef();
		}

		void UpdateCamera(GameTime gameTime)
		{
			UpdateCameraRotation(gameTime);
			UpdateCameraMovement(gameTime);

			//_camera.Width = _context.SwapChain.BackbufferViewport.Width / 256;
			//_camera.Height = _context.SwapChain.BackbufferViewport.Height / 256;

			_camera.AspectRatio = Application.Get().Window.Context.SwapChain.BackbufferViewport.Width /
									Application.Get().Window.Context.SwapChain.BackbufferViewport.Height;

			_camera.Update();
		}

		double cameraRotationSpeedX = 0.0001f;
		double cameraRotationSpeedY = 0.0001f;

		bool b = true;

		void UpdateCameraRotation(GameTime gameTime)
		{
			if(b)
			{
				b = false;
				return;
			}

			let mouseMovement = Input.GetRawMouseMovement();

			if(mouseMovement.X == 0 && mouseMovement.Y == 0)
				return;

			Vector3 rotation = _camera.Rotation;

			rotation.Y = (float)(rotation.Y + mouseMovement.X * cameraRotationSpeedX * gameTime.FrameTime.TotalMilliseconds);
			rotation.X = (float)(rotation.X + mouseMovement.Y * cameraRotationSpeedY * gameTime.FrameTime.TotalMilliseconds);

			rotation.X = Math.Clamp(rotation.X, -Math.PI_f / 2, Math.PI_f / 2);

			_camera.Rotation = rotation;
		}

		float movementSpeed = 2;
		float movementSpeedFast = 20;

		void UpdateCameraMovement(GameTime gameTime)
		{
			Vector3 movement = .();

			if(Input.IsKeyPressed(Key.W))
			{
				movement.Z += 1;
			}
			if(Input.IsKeyPressed(Key.S))
			{
				movement.Z -= 1;
			}

			if(Input.IsKeyPressed(Key.A))
			{
				movement.X -= 1;
			}
			if(Input.IsKeyPressed(Key.D))
			{
				movement.X += 1;
			}
			
			if(Input.IsKeyPressed(Key.Space))
			{
				movement.Y += 1;
			}
			if(Input.IsKeyPressed(Key.Control))
			{
				movement.Y -= 1;
			}

			if(movement != .Zero)
				movement.Normalize();

			movement *= (float)(gameTime.FrameTime.TotalSeconds);

			Matrix rot = .RotationY(_camera.Rotation.Y) * .RotationX(_camera.Rotation.X);

			movement = ((Vector4)(rot * Vector4(movement, 1.0f))).XYZ;
			
			float speed = Input.IsKeyPressed(Key.Shift) ? movementSpeedFast : movementSpeed;

			_camera.Position += movement * speed;
		}

		Ray ray = .(.(0, 128, 0), .UnitZ);

		public override void Update(GameTime gameTime)
		{
			UpdateCamera(gameTime);

			_world.ChunkManager.Update(_camera.Position);

			//RenderCommand.Clear(null, .(0.2f, 0.2f, 0.2f));
			RenderCommand.Clear(null, .CornflowerBlue);
			RenderCommand.Clear(_depthStencilTarget, 1.0f, 0, .Depth);

			// Draw test geometry
			_depthStencilTarget.Bind();
			_context.SetRenderTarget(null);
			_context.BindRenderTargets();

			_context.SetRasterizerState(_rasterizerState);

			_context.SetViewport(_context.SwapChain.BackbufferViewport);

			Renderer.BeginScene(_camera);
			
			_opaqueBlendState.Bind();

			for(int x < 20)
			for(int y < 20)
			{
				if((x + y) % 2 == 0)
					_effect.Variables["BaseColor"].SetData(_squareColor0);
				else
					_effect.Variables["BaseColor"].SetData(_squareColor1);

				Matrix transform = Matrix.Translation(x * 0.2f, y * 0.2f, 0) * Matrix.Scaling(0.1f);
				Renderer.Submit(_quadGeometryBinding, _effect, transform);
			}
			
			//_effect.Variables["BaseColor"].SetData(_squareColor1);
			
			_texture.Bind();
			Renderer.Submit(_quadGeometryBinding, _textureEffect, .Scaling(1.5f));
			
			_alphaBlendState.Bind();

			_ge_logo.Bind();
			Renderer.Submit(_quadGeometryBinding, _textureEffect, .Scaling(1.5f));

			_texture.Bind();

			intersectInfo.Coordinate = _world.RaycastBlock(.(_camera.Position, _camera.Transform.Forward), 10, _cubeGeo, _textureEffect, out intersectInfo.Location, out intersectInfo.Face);

			Renderer.Submit(_cubeGeo, _textureEffect, .Translation((Vector3)intersectInfo.Coordinate));
			
			Renderer.Submit(_cubeGeo, _textureEffect, .Translation(intersectInfo.Location) * .Scaling(0.1f) * .Translation(-0.5f.XXX));

			if(intersectInfo.Face != .None)
			{
				if(Input.IsMouseButtonPressing(.LeftButton))
				{
					_world.SetBlock(intersectInfo.Coordinate, 0);
				}
				else if(Input.IsMouseButtonPressing(.RightButton))
				{
					var newBlockCoord = intersectInfo.Coordinate;

					switch(intersectInfo.Face)
					{
					case .Front:
						newBlockCoord.Z--;
					case .Back:
						newBlockCoord.Z++;
					case .Left:
							newBlockCoord.X--;
					case .Right:
							newBlockCoord.X++;
					case .Bottom:
						newBlockCoord.Y--;
					case .Top:
						newBlockCoord.Y++;
					default:
						Log.ClientLogger.Error("Unknown block face.");
					}

					_world.SetBlock(newBlockCoord, 1);
				}
			}

			_world.ChunkManager.Draw();

			Renderer.EndScene();
		}

		struct IntersectionInfo
		{
			public Int32_3 Coordinate;
			public Vector3 Location;
			public BlockFace Face;
		}

		IntersectionInfo intersectInfo;

		ColorRGBA _squareColor0 = ColorRGBA.CornflowerBlue;
		ColorRGBA _squareColor1;

		public override void OnEvent(Event event)
		{
			EventDispatcher dispatcher = scope EventDispatcher(event);

			dispatcher.Dispatch<ImGuiRenderEvent>(scope (e) => OnImGuiRender(e));
			dispatcher.Dispatch<WindowResizeEvent>(scope (e) => OnWindowResize(e));
		}

		private bool OnWindowResize(WindowResizeEvent e)
		{
			_depthStencilTarget?.ReleaseRef();
			
			_depthStencilTarget = new DepthStencilTarget(_context, _context.SwapChain.Width, _context.SwapChain.Height);

			return false;
		}

		private bool OnImGuiRender(ImGuiRenderEvent e)
		{
			_world.ChunkManager.OnImGuiRender();

			ImGui.Begin("Test");

			ImGui.LabelText("Looked at block", $"Coord: {intersectInfo.Coordinate}, Block Face: {intersectInfo.Face}, Location: {intersectInfo.Location}");

			ImGui.DragFloat("Slow Speed", &movementSpeed, 1.0f, 0.01f, 100.0f);
			ImGui.DragFloat("Fast Speed", &movementSpeedFast, 1.0f, 1f, 10000.0f);

			Vector3 fwd = _camera.Transform.Forward;

			ImGui.DragFloat3("Forward", *(float[3]*)(void*)&fwd, 1.0f, float.NegativeInfinity, float.PositiveInfinity);

			Vector3 camPos = _camera.Position;

			ImGui.DragFloat3("Position", *(float[3]*)(void*)&camPos, 1.0f, float.NegativeInfinity, float.PositiveInfinity);

			_camera.Position = camPos;

			ImGui.ColorEdit3("Square Color", ref _squareColor0);

			_squareColor1 = ColorRGBA.White - _squareColor0;

			_camera.Position = camPos;




			ImGui.End();

			return false;
		}
	}
}
