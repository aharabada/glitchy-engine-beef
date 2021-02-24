using System;
using GlitchyEngine;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using ImGui;
using GlitchyEngine.ImGui;
using GlitchyEngine.Events;
using System.Diagnostics;

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

		GeometryBinding _chunkGeoBinding ~ _?.ReleaseRef();

		GeometryBinding _geometryBinding ~ _?.ReleaseRef();

		GeometryBinding _quadGeometryBinding ~ _?.ReleaseRef();

		RasterizerState _rasterizerState ~ delete _;

		Effect _effect ~ _?.ReleaseRef();
		Effect _textureEffect ~ _?.ReleaseRef();

		GraphicsContext _context ~ _?.ReleaseRef();

		Texture2D _texture ~ _?.ReleaseRef();
		Texture2D _ge_logo ~ _?.ReleaseRef();

		BlendState _alphaBlendState ~ _?.ReleaseRef();
		BlendState _opaqueBlendState ~ _?.ReleaseRef();

		DepthStencilTarget _depthStencilTarget ~ _?.ReleaseRef();

		ChunkManager _chunkManager ~ delete _;

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
			
			_chunkManager = new ChunkManager(_context, _vertexLayout, _world);
			_chunkManager.Texture = _texture..AddRef();
			_chunkManager.TextureEffect = _textureEffect..AddRef();
		}
		/*
		void GenerateTerrain(ref VoxelChunk vc)
		{
			Stopwatch sw = .StartNew();
			/*
			float[] gradient = scope .[VoxelChunk.SizeY](?);
			for(int y = 0; y < VoxelChunk.SizeY; y++)
			{
				gradient[y] = y / (float)(VoxelChunk.SizeY - 1);
			}
			*/
			//Random r = scope Random();
			let groundNoise = scope FastNoiseLite.FastNoiseLite();
			groundNoise.SetFractalOctaves(6);
			groundNoise.SetFractalType(.FBm);
			groundNoise.SetFrequency(0.0075f);

			let perturbNoise = scope FastNoiseLite.FastNoiseLite();
			perturbNoise.SetFractalOctaves(6);
			perturbNoise.SetFractalType(.FBm);
			perturbNoise.SetFrequency(0.005f);

			for(int x < VoxelChunk.SizeX)
			for(int y < VoxelChunk.SizeY)
			for(int z < VoxelChunk.SizeZ)
			{
				//(int X, int Y, int Z) coordinate = (x, y, z);

				// randomize coordinate
				//coordinate.Y += (int)(groundNoise.GetNoise(x, 0, z) * VoxelChunk.SizeY / 4);//r.Next(-VoxelChunk.SizeY / 4, VoxelChunk.SizeY / 4);


				//float pertubation = perturbNoise.GetNoise(y * 0.5f, -y * 0.5f) * 30;

				//coordinate.Y += (int)(groundNoise.GetNoise(x + pertubation, z + pertubation) * VoxelChunk.SizeY / 4);//r.Next(-VoxelChunk.SizeY / 4, VoxelChunk.SizeY / 4);

				//coordinate.Y = Math.Clamp(coordinate.Y, 0, VoxelChunk.SizeY - 1);

				// get Gradient for coordinate
				//float gradientValue = gradient[coordinate.Y];

				float cy = (float)y;
				cy += groundNoise.GetNoise(x, cy * 0.5f, z) * (VoxelChunk.SizeY / 4.0f);

				float gradientValue = cy / (float)(VoxelChunk.SizeY - 1);

				// determine whether or not gradient value is air
				uint8 stepValue = gradientValue < 0.5f ? 1 : 0;

				vc.Data[x][y][z] = stepValue;
			}

			sw.Stop();

			Debug.WriteLine($"Terrain Generation: {sw.ElapsedMilliseconds}ms");

			delete sw;

			/*
			let elevationNoise = scope FastNoiseLite.FastNoiseLite();
			//elevationNoise.

			for(int x < VoxelChunk.SizeX)
			for(int y < VoxelChunk.SizeY)
			for(int z < VoxelChunk.SizeZ)
			{
				/*
				float elevation = elevationNoise.GetNoise(x, z);

				int height = (int)((elevation) * 64 + 64);
				
				for(int y < height)
				{
					vc.Data[x][y][z] = 1;
				}
				*/

				vc.Data[x][y][z] = ((elevationNoise.GetNoise(x, y, z) * 64) + y) < 64 ? 1 : 0;
				//vc.Data[x][y][z] = elevationNoise.GetNoise(x, y, z) > 0.0f ? 1 : 0;

				//vc.Data[x][y][z] = (noise.GetNoise(x, y, z) + 0.5f) < 0 ? 0 : 1;
			}
			*/
			/*
			for(int x < VoxelChunk.SizeX)
			for(int z < VoxelChunk.SizeZ)
			{
				float f = noise.GetNoise(x, z);

				int yMax = (int)(f * VoxelChunk.SizeY);

				for(int y < yMax)
				{
					vc.Data[x][y][z] = 1;
				}
			}
			*/
		}

		struct GroundLayer
		{
			public int Depth;
			public uint8 BlockType;
		}

		void GroundLayers(ref VoxelChunk vc)
		{
			GroundLayer[3] layers;
			layers[0] = .()
			{
				Depth = 1,
				BlockType = 3
			};
			layers[1] = .()
			{
				Depth = 4,
				BlockType = 2
			};
			layers[2] = .()
			{
				Depth = 0,
				BlockType = 1
			};

			for(int x < VoxelChunk.SizeX)
			for(int z < VoxelChunk.SizeZ)
			{
				int currentLayer = 0;
				int currentDepth = 0;

				for(int y = VoxelChunk.SizeY - 1; y > 0; y--)
				{
					if(vc.Data[x][y][z] == 0)
					{
						currentDepth--;
						
						if(currentDepth < 0)
						{
							currentDepth = 0;

							currentLayer--;

							if(currentLayer < 0)
								currentLayer = 0;
						}
					}
					else
					{
						vc.Data[x][y][z] = layers[currentLayer].BlockType;

						currentDepth++;

						if(currentDepth >= layers[currentLayer].Depth)
						{
							if(currentLayer >= layers.Count - 1)
							{
								currentLayer = layers.Count - 1;
							}
							else
							{
								currentDepth = 0;
								currentLayer++;
							}
						}
					}
				}
			}
		}

		void GenTestChunk()
		{
			VoxelChunk* vc = new .();

			GenerateTerrain(ref *vc);
			GroundLayers(ref *vc);
			/*
			Random r = scope Random();
			
			for(int x < VoxelChunk.SizeX)
			for(int y < VoxelChunk.SizeY)
			for(int z < VoxelChunk.SizeZ)
			{
				vc.Data[x][y][z] = (.)y;//(.)r.Next(0, 2);
			}

			for(int x < VoxelChunk.SizeX)
			for(int y < VoxelChunk.SizeY)
			for(int z < VoxelChunk.SizeZ)
			{
				if(vc.Data[x][y][z] < VoxelChunk.SizeY / 2)
					vc.Data[x][y][z] = 1;
				else
					vc.Data[x][y][z] = 0;
			}
			*/
			/*
			vc.Data[8][VoxelChunk.SizeY / 2][8] = 1;
			vc.Data[8][VoxelChunk.SizeY / 2 + 1][8] = 1;
			vc.Data[8][VoxelChunk.SizeY / 2 + 2][8] = 1;
			vc.Data[8][VoxelChunk.SizeY / 2 + 3][8] = 1;
			
			for(int x = 6; x < 11; x++)
			for(int y = VoxelChunk.SizeY / 2 + 2; y < VoxelChunk.SizeY / 2 + 5; y++)
			for(int z = 6; z < 11; z++)
			{
				vc.Data[x][y][z] = 1;
			}
			*/
			_chunkGeoBinding = voxelGeoGen.GenerateGeometry(*vc);

			delete vc;
		}
		*/
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

			let mouseMovement = Input.GetMouseMovement();

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

		public override void Update(GameTime gameTime)
		{
			UpdateCamera(gameTime);

			_chunkManager.Update(_camera.Position);

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
			
			_effect.Variables["BaseColor"].SetData(_squareColor1);
			
			_texture.Bind();
			Renderer.Submit(_quadGeometryBinding, _textureEffect, .Scaling(1.5f));
			
			_alphaBlendState.Bind();

			_ge_logo.Bind();
			Renderer.Submit(_quadGeometryBinding, _textureEffect, .Scaling(1.5f));

			_chunkManager.Draw();

			//_texture.Bind();
			//Renderer.Submit(_chunkGeoBinding, _textureEffect, .Identity);

			Renderer.EndScene();
		}

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
			_chunkManager.OnImGuiRender();

			ImGui.Begin("Test");

			ImGui.DragFloat("Slow Speed", &movementSpeed, 1.0f, 0.01f, 100.0f);
			ImGui.DragFloat("Fast Speed", &movementSpeedFast, 1.0f, 1f, 10000.0f);

			Vector3 camPos = _camera.Position;

			ImGui.DragFloat3("Position", *(float[3]*)(void*)&camPos, 1.0f, float.NegativeInfinity, float.PositiveInfinity);

			_camera.Position = camPos;

			ImGui.ColorEdit3("Square Color", ref _squareColor0);

			_squareColor1 = ColorRGBA.White - _squareColor0;

			ImGui.End();

			return false;
		}
	}
}
