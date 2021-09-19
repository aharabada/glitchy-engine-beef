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
using GlitchyEngine.Renderer.Text;
using System.IO;
using msdfgen;

namespace Sandbox
{
	class ExampleLayer2D : Layer
	{
		struct Vertexy : IVertexData
		{
			public Vector2 Position;

			public this(Vector2 position)
			{
				Position = position;
			}

			public this(float x, float y)
			{
				Position = .(x, y);
			}

			public static VertexElement[] VertexElements ~ delete _;

			public static VertexElement[] IVertexData.VertexElements => VertexElements;

			static this()
			{
				VertexElements = new VertexElement[]
				(
					VertexElement(.R32G32_Float, "POSITION")
				);
			}
		}

		RasterizerState _rasterizerState ~ _?.ReleaseRef();

		GraphicsContext _context ~ _?.ReleaseRef();
		DepthStencilTarget _depthTarget ~ _?.ReleaseRef();

		Texture2D _texture ~ _?.ReleaseRef();
		Texture2D _ge_logo ~ _?.ReleaseRef();

		BlendState _alphaBlendState ~ _?.ReleaseRef();
		BlendState _opaqueBlendState ~ _?.ReleaseRef();

		EffectLibrary _effectLibrary ~ delete _;

		EcsWorld _world = new EcsWorld() ~ delete _;

		Renderer2D Renderer2D ~ delete _;

		Texture2D _testTexture ~ _?.ReleaseRef();

		String testText ~ delete _;

		Effect _msdfEffect ~ _.ReleaseRef();

		TextureViewer _textureViewer ~ delete _;

		[AllowAppend]
		public this() : base("Example")
		{
			Application.Get().Window.IsVSync = false;

			_context = Application.Get().Window.Context..AddRef();

			_effectLibrary = new EffectLibrary(_context);

			_effectLibrary.LoadNoRefInc("content\\Shaders\\basicShader.hlsl");

			// Create rasterizer state
			GlitchyEngine.Renderer.RasterizerStateDescription rsDesc = .(.Solid, .Back, true);
			_rasterizerState = new RasterizerState(_context, rsDesc);

			_depthTarget = new DepthStencilTarget(_context, _context.SwapChain.Width, _context.SwapChain.Height);

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

			Renderer2D = new Renderer2D(_context, _effectLibrary);
			//Init2D();

			Texture2DDesc desc = .();
			desc.Format = .R8G8B8A8_UNorm;
			desc.Width = 2;
			desc.Height = 2;
			desc.ArraySize = 1;
			desc.CpuAccess = .None;
			desc.MipLevels = 1;
			desc.Usage = .Default;

			_testTexture = new Texture2D(_context, desc);

			Color[4] colors = .(
				.Red, .Green,
				.Blue, .White);
			
			_testTexture.SetData<Color>(&colors, 0, 1, 1, 1);

			fonty = new Font(_context, "C:\\Windows\\Fonts\\arial.ttf", 64, true, 'A', 16);
			var japanese = new Font(_context, "C:\\Windows\\Fonts\\YuGothM.ttc", 64, true, '\0', 1);
			var emojis = new Font(_context, "C:\\Windows\\Fonts\\seguiemj.ttf", 64, true, '😂' - 10, 1);
			var mathstuff = new Font(_context, "C:\\Windows\\Fonts\\cambria.ttc", 64, true, 'α', 1);
			fonty.Fallback = japanese..ReleaseRefNoDelete();
			japanese.Fallback = emojis..ReleaseRefNoDelete();
			emojis.Fallback = mathstuff..ReleaseRefNoDelete();

			// Load test text
			var result = File.ReadAllText("test.txt", testText = new String(), true);
			//Log.EngineLogger.Assert(result)

			_msdfEffect = _effectLibrary.Load("content\\Shaders\\msdfShader.hlsl");

			_textureViewer = new TextureViewer(_context, Renderer2D, _effectLibrary);
		}

		double F26Dot6ToDouble(uint16 value)
		{
			return (double(value) / 64.0);
		}

		void DoTheThing(FreeType.FT_Face fontFace, double pixelSizeY)
		{
			double unitsPerEm = F26Dot6ToDouble(fontFace.units_per_EM);

			// How much we have to scale the geometry to fit it into our desired pixels
			double geometryScaler = pixelSizeY / unitsPerEm;

			// prepare shape
			
			double advance = 0;

			var glyphIndex = FreeType.FreeType.Get_Char_Index(fonty.[Friend]_face, 'ß');

			Shape shape;
			msdfgen.LoadGlyph(out shape, &fonty.[Friend]_face, glyphIndex, out advance);

			shape.Normalize();

			var bounds = shape.GetBounds();
			
			msdfgen.EdgeColoringSimple(shape, 3.0);

			// prepare projection

			double scale = geometryScaler;
			double range = 4.0 / geometryScaler;

			int width;
			int height;
			
			double translationX;
			double translationY;

			if(bounds.Left < bounds.Right && bounds.Bottom < bounds.Top)
			{
				double l = bounds.Left;
				double r = bounds.Right;
				double b = bounds.Bottom;
				double t = bounds.Top;

				l -= 0.5 * range;
				b -= 0.5 * range;
				r += 0.5 * range;
				t += 0.5 * range;

				// TODO: miter?!

				double w = scale * (r - l);
				double h = scale * (t - b);

				width = (int)Math.Ceiling(w) + 1;
				height = (int)Math.Ceiling(h) + 1;

				translationX = -l + 0.5 * (width - w) / scale;
				translationY = -b + 0.5 * (height - h) / scale;
			}
			else
			{
				width = 0;
				height = 0;
				translationX = 0;
				translationY = 0;
			}

			msdfgen.Projection projection = .();
			projection.ScaleX = scale;
			projection.ScaleY = scale;

			projection.TranslationX = translationX;
			projection.TranslationY = translationY;

			/*

			void GlyphGeometry::wrapBox(double scale, double range, double miterLimit) {
			    scale *= geometryScale;
			    range /= geometryScale;
			    box.range = range;
			    box.scale = scale;
			    if (bounds.l < bounds.r && bounds.b < bounds.t) {
			        double l = bounds.l, b = bounds.b, r = bounds.r, t = bounds.t;
			        l -= .5*range, b -= .5*range;
			        r += .5*range, t += .5*range;
			        if (miterLimit > 0)
			            shape.boundMiters(l, b, r, t, .5*range, miterLimit, 1);
			        double w = scale*(r-l);
			        double h = scale*(t-b);
			        box.rect.w = (int) ceil(w)+1;
			        box.rect.h = (int) ceil(h)+1;
			        box.translate.x = -l+.5*(box.rect.w-w)/scale;
			        box.translate.y = -b+.5*(box.rect.h-h)/scale;
			    } else {
			        box.rect.w = 0, box.rect.h = 0;
			        box.translate = msdfgen::Vector2();
			    }
			}

			*/

			int x = (int)pixelSizeY;
			int y = (int)pixelSizeY;

			Bitmap<ColorRGB, const 1> bitmap = .((.)x, (.)y);

			MSDFGeneratorConfig config = .();

			msdfgen.GenerateMSDF(*(Bitmap<float, const 3>*)&bitmap, shape, projection, range, config);
			
			// Save png
			/*
			uint8[] data = new uint8[x * y * 3];

			for(int i = 0; i < x * y * 3; i++)
			{
				float f = bitmap.Pixels[i / 3].Red / 2f + 0.5f;
				float f2 = bitmap.Pixels[i / 3].Green / 2f + 0.5f;
				float f3 = bitmap.Pixels[i / 3].Blue / 2f + 0.5f;

				data[i++] = (uint8)Math.Clamp(256.0f * f, 0, 255);
				data[i++] = (uint8)Math.Clamp(256.0f * f2, 0, 255);
				data[i] = (uint8)Math.Clamp(256.0f * f3, 0, 255);
			}

			// TODO: free shape

			LodePng.LodePng.EncodeFile("test.png", data.Ptr, (.)x, (.)y, .RGB, 8);
			*/
			Texture2DDesc desc;
			desc.Width = (.)x;
			desc.Height = (.)y;
			desc.Format = .R8G8B8A8_SNorm;
			desc.MipLevels = 1;
			desc.Usage = .Immutable;
			desc.CpuAccess = .None;
			desc.ArraySize = 1;

			_dasTestA = new Texture2D(_context, desc);

			int8[] pixels = new int8[x * y * 4];
			
			int8 ToInt8(float f) => (.)Math.Clamp(127f * f, int8.MinValue, int8.MaxValue);

			//for(int i = 0; i < x * y; i++)
			for(int iy = 0; iy < y; iy++)
			for(int ix = 0; ix < x; ix++)
			{
				ColorRGB pixel = bitmap.Pixels[iy * y + ix];

				float f = pixel.Red;// / 2f + 0.5f;
				float f2 = pixel.Green;// / 2f + 0.5f;
				float f3 = pixel.Blue;// / 2f + 0.5f;

				int index = ((y - iy - 1) * y + ix) * 4;

				pixels[index + 0] = ToInt8(f);
				pixels[index + 1] = ToInt8(f2);
				pixels[index + 2] = ToInt8(f3);
				pixels[index + 3] = 0;

				//pixels[(y - iy - 1) * y + ix] = Color(f, f2, f3);
			}

			_dasTestA.SetData<Color>((.)pixels.Ptr, 0, 0, (.)x, (.)y);
			//_dasTestA.SetData<uint8>(pixelData.Ptr, 0, 0, (.)x, (.)y);
		}

		Texture2D _dasTestA ~ _.ReleaseRef();

		Font fonty ~ _.ReleaseRef();

		VertexLayout layout ~ _?.ReleaseRef();

		GeometryBinding quadBinding ~ _?.ReleaseRef();

		/*
		void Init2D()
		{
			var effect = _effectLibrary.Load("content\\Shaders\\render2dShader.hlsl", "Renderer2D");

			layout = new VertexLayout(_context, Vertexy.VertexElements, effect.VertexShader);

			effect.ReleaseRef();

			VertexBuffer quadVertices = new VertexBuffer(_context, typeof(Vertexy), 4, .Immutable);

			Vertexy[4] vertices = .(
				Vertexy(0, 0),
				Vertexy(0, 1),
				Vertexy(1, 1),
				Vertexy(1, 0)
				);

			quadVertices.SetData(vertices);

			IndexBuffer quadIndices = new IndexBuffer(_context, 6, .Immutable);

			uint16[6] indices = .(
					0, 1, 2,
					2, 3, 0
				);

			quadIndices.SetData(indices);

			quadBinding = new GeometryBinding(_context);
			quadBinding.SetPrimitiveTopology(.TriangleList);
			quadBinding.SetVertexBufferSlot(quadVertices, 0);
			quadBinding.SetVertexLayout(layout);
			quadBinding.SetIndexBuffer(quadIndices);

			quadVertices.ReleaseRef();
			quadIndices.ReleaseRef();
		}
		*/

		Entity _cameraEntity;

		void InitEcs()
		{
			_world.Register<TransformComponent>();
			_world.Register<MeshComponent>();
			_world.Register<CameraComponent>();

			// Create camera entity
			_cameraEntity = _world.NewEntity();
			var cameraTransform = _world.AssignComponent<TransformComponent>(_cameraEntity);
			var camera = _world.AssignComponent<CameraComponent>(_cameraEntity);
			*cameraTransform = TransformComponent();
			camera.NearPlane = 0.1f;
			camera.FarPlane = 10.0f;
			camera.FovY = Math.PI_f / 4;
			cameraTransform.Position = .(0, -1, -5);
			/*
			for(int x < 20)
			for(int y < 20)
			{
				Entity entity = _world.NewEntity();

				var transform = _world.AssignComponent<TransformComponent>(entity);
				transform.Transform = Matrix.Translation(x * 0.2f, y * 0.2f, 0) * Matrix.Scaling(0.1f);

				var mesh = _world.AssignComponent<MeshComponent>(entity);
				mesh.Mesh = _quadGeometryBinding;
			}
			*/
		}

		public override void Update(GameTime gameTime)
		{
			var cameraTransform = _world.GetComponent<TransformComponent>(_cameraEntity);

			if(Application.Get().Window.IsActive)
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

				cameraTransform.Position += .(movement, 0);
				//Runtime.NotImplemented();
				//cameraTransform.Update();
			}

			var camera = _world.GetComponent<CameraComponent>(_cameraEntity);
			camera.Aspect = Application.Get().Window.Context.SwapChain.BackbufferViewport.Width /
									Application.Get().Window.Context.SwapChain.BackbufferViewport.Height;

			TransformSystem.Update(_world);

			RenderCommand.Clear(null, .(0.2f, 0.2f, 0.2f));
			
			_depthTarget..Clear(1.0f, 0, .Depth).Bind();
			// Draw test geometry
			_context.SetRenderTarget(null);
			_context.BindRenderTargets();

			_context.SetRasterizerState(_rasterizerState);

			_context.SetViewport(_context.SwapChain.BackbufferViewport);

			/*
			Renderer2D.Begin(.FrontToBack, .(80, 80));
			
			//_opaqueBlendState.Bind();
			_alphaBlendState.Bind();
			
			//Renderer2D.DrawQuad(5, 5, 1, 1, .Red);
			//Renderer2D.DrawQuad(5, 5, 1, 1, .Blue);

			Random r = scope Random(1337);

			//_texture.Bind(0);
			//_ge_logo.Bind(1);
			
			for(int x < 40)
			for(int y < 40)
			{
				int i = (x + y) % 2 + 1;//((x + (y * 40)) ^ (x * y)) % 3;

				if(i == 1)
				{
					Renderer2D.Draw(_texture, 2 * x, 2 * y, 1, 1, .(r.Next(0, 256), r.Next(0, 256), r.Next(0, 256)), 10);
				}
				else if(i == 2)
				{
					Renderer2D.Draw(_ge_logo, 2 * x, 2 * y, 1, 1, .(r.Next(0, 256), r.Next(0, 256), r.Next(0, 256)), 10);
				}
			}
			
			Renderer2D.Draw(_ge_logo, 0, 0, 180, 40, .White, 20);

			/*
			Renderer2D.Draw(_texture, 10, 50, 100, 100, .White);

			Renderer2D.Draw(_texture, 120, 50, 100, 100, .White);

			Renderer2D.Draw(_texture, 10, 160, 100, 100, .White);

			Renderer2D.Draw(_texture, 120, 160, 100, 100, .White);
			*/
			//_alphaBlendState.Bind();

			//Renderer2D.Draw(_ge_logo, 80, 50, 100, 100, .White);

			Renderer2D.End();
			*/

			_alphaBlendState.Bind();
			Renderer2D.Begin(.FrontToBack, .(_context.SwapChain.Width, _context.SwapChain.Height));
			
			Renderer2D.Draw(null, 0, 0, 502, 502, .Black, 5);
			
			// Hallo Welt, wie geht es dir? 😂😂😂\nMir geht es gut, danke der Nachfrage. Wie geht es dir?\nMir geht es hervorragend und besser noch: meine Engine kann endlich Text rendern!💕❤\n und es scheint ganz in ordnung zu sein.
			//FontRenderer.DrawText(Renderer2D, fonty, testText, 0, 0, .White, .White, 32);

			Renderer2D.End();

			Renderer2D.Begin(.FrontToBack, .(_context.SwapChain.Width, _context.SwapChain.Height), 100, _msdfEffect);

			_msdfEffect.Variables["screenPixelRange"].SetData(size / 64f * 4.0f);

			Renderer2D.Draw(_dasTestA, 1, 1, size, size);

			// TODO: SDFs in Font Atlas packen

			Renderer2D.End();
		}

		int32 size = 500;

		ColorRGBA _squareColor0 = ColorRGBA.CornflowerBlue;
		ColorRGBA _squareColor1;

		public override void OnEvent(Event event)
		{
			EventDispatcher dispatcher = EventDispatcher(event);

			dispatcher.Dispatch<ImGuiRenderEvent>(scope (e) => OnImGuiRender(e));

			dispatcher.Dispatch<WindowResizeEvent>(scope (e) => OnWindowResize(e));
		}

		private bool OnImGuiRender(ImGuiRenderEvent e)
		{
			/*
			ImGui.Begin("SDF Test");

			ImGui.InputInt("Size", &size);

			float f = (size / 64f * 4.0f);

			ImGui.Text($"SPR: {f}");

			ImGui.End();
			*/
			//return true;

			/*
			return true;

			ImGui.Begin("Test");

			ImGui.ColorEdit3("Square Color", ref _squareColor0);

			_squareColor1 = ColorRGBA.White - _squareColor0;

			//ImGui.Begin

			//ImGui.Image(fonty.[Friend]_atlas.[Friend]nativeView, .(100, 200));
			//ImGui.Scrollbar(.X);
			//ImGui.Image(fonty.[Friend]_atlas.[Friend]nativeView, .(fonty.[Friend]_atlas.Width, fonty.[Friend]_atlas.Height), .(0.0f, 0.0f), .(1.0f, 1.0f), .(1.0f, 1.0f, 1.0f, 1.0f), .(1.0f, 0, 0, 1));

			ImGui.End();
			*/

			_textureViewer.ViewTexture(fonty.[Friend]_atlas);

			_context.SetRenderTarget(null);
			_depthTarget.Bind();
			_context.BindRenderTargets();

			return false;
		}

		float zoom = 1.0f;

		private void TextureViewer()
		{
			ImGui.Begin("Texture Viewer");

			ImGui.SliderFloat("Zoom", &zoom, 0.01f, 100.0f);

			ImGui.BeginChild("imageChild", default, true, .HorizontalScrollbar);

			ImGui.Image(fonty.[Friend]_atlas.[Friend]nativeResourceView, .(fonty.[Friend]_atlas.Width * zoom, fonty.[Friend]_atlas.Height * zoom), .(0.0f, 0.0f), .(1.0f, 1.0f), .(1.0f, 1.0f, 1.0f, 1.0f), .(1.0f, 0, 0, 1));

			ImGui.EndChild();

			ImGui.End();
		}

		private bool OnWindowResize(WindowResizeEvent e)
		{
			_depthTarget.ReleaseRef();
			_depthTarget = new DepthStencilTarget(_context, _context.SwapChain.Width, _context.SwapChain.Height);

			return false;
		}
	}

	class SandboxApp2D : Application
	{
		public this()
		{
			PushLayer(new ExampleLayer2D());
		}

#if SANDBOX_2D		
		[Export, LinkName("CreateApplication")]
#endif
		public static Application CreateApplication()
		{
			return new SandboxApp2D();
		}
	}
}