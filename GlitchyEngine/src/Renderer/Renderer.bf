using GlitchyEngine.Math;
using GlitchyEngine.World;
using System.Collections;
using System;

namespace GlitchyEngine.Renderer
{
	public class Renderer
	{
		struct SceneConstants
		{
			public Matrix ViewProjection;
			public Vector3 CameraPosition;
			public RenderTarget2D CameraTarget;
		}

		struct ObjectConstants
		{
			public Matrix Transform;
		}

		class GBuffer
		{
			private uint32 _width;
			private uint32 _height;
			
			public DepthStencilTarget DepthStencil;
			public RenderTarget2D Color ~ _?.ReleaseRef();
			public RenderTarget2D Normal ~ _?.ReleaseRef();
			public RenderTarget2D Position ~ _?.ReleaseRef();

			public void EnsureSize(uint32 width, uint32 height)
			{
				if (width <= _width && height <= _height)
					return;

				if (_width == 0 || _height == 0)
				{
					// Note: Depth-Buffer in Color-Target for convenience
					RenderTarget2DDescription colorDesc = .(.R8G8B8A8_UNorm, width, height, 1, 1, .D24_UNorm_S8_UInt);
					Color = new RenderTarget2D(colorDesc);

					RenderTarget2DDescription normalDesc = .(.R32G32B32A32_Float, width, height);
					Normal = new RenderTarget2D(normalDesc);

					RenderTarget2DDescription positionDesc = .(.R32G32B32A32_Float, width, height);
					Position = new RenderTarget2D(positionDesc);
				}

				_width = width;
				_height = height;

				Color.Resize(_width, _height);
				Normal.Resize(_width, _height);
				Position.Resize(_width, _height);

				DepthStencil = Color.DepthStencilTarget;
			}

			public void Bind()
			{
				RenderCommand.SetDepthStencilTarget(DepthStencil);

				RenderCommand.UnbindRenderTargets();
				RenderCommand.SetRenderTarget(Color, 0);
				RenderCommand.SetRenderTarget(Normal, 1);
				RenderCommand.SetRenderTarget(Position, 2);

				RenderCommand.BindRenderTargets();
			}
		}

		static internal GraphicsContext _context ~ _?.ReleaseRef();

		//static Buffer<SceneConstants> _sceneConstants ~ _?.ReleaseRef();

		//static Buffer<ObjectConstants> _objectConstants ~ _?.ReleaseRef();

		static SceneConstants _sceneConstants;

		static Effect LineEffect ~ _?.ReleaseRef();
		static VertexBuffer LineVertices ~ _?.ReleaseRef();
		static GeometryBinding LineGeometry ~ _?.ReleaseRef();

		static GBuffer _gBuffer ~ delete _;
		static Effect TestFullscreenEffect ~ _?.ReleaseRef();

		public static void Init(GraphicsContext context, EffectLibrary effectLibrary)
		{
			Debug.Profiler.ProfileFunction!();

			_context = context..AddRef();
			/*
			_sceneConstants = new Buffer<SceneConstants>(.(0, .Constant, .Dynamic, .Write));
			_sceneConstants.Update();

			_objectConstants = new Buffer<ObjectConstants>(.(0, .Constant, .Dynamic, .Write));
			_objectConstants.Update();
			*/

			RenderCommand.Init();
			Renderer2D.Init();

			InitLineRenderer(effectLibrary);
			InitDeferredRenderer(effectLibrary);

			_gBuffer = new GBuffer();
		}

		public static void Deinit()
		{
			Debug.Profiler.ProfileFunction!();

			Renderer2D.Deinit();
		}

		static void InitLineRenderer(EffectLibrary effectLibrary)
		{
			Debug.Profiler.ProfileFunction!();

			LineEffect = effectLibrary.Load("content\\Shaders\\lineShader.hlsl");

			LineGeometry = new GeometryBinding();
			LineGeometry.SetPrimitiveTopology(.LineList);
			
			Vector4[2] vertices = .(.Zero, .Zero);
			LineVertices = new VertexBuffer(sizeof(Vector4), 2, .Dynamic, .Write);
			LineVertices.SetData<Vector4>(vertices, 0, .WriteDiscard);
			LineGeometry.SetVertexBufferSlot(LineVertices, 0);
			
			uint16[2] indices = .(0, 1);
			IndexBuffer indexBuffer = new IndexBuffer(2, .Immutable);
			indexBuffer.SetData(indices);
			LineGeometry.SetIndexBuffer(indexBuffer);
			indexBuffer.ReleaseRef();

			VertexElement[] vertexElements = new VertexElement[1];
			vertexElements[0] = .(.R32G32B32_Float, "POSITION");
			VertexLayout layout = new VertexLayout(vertexElements, true, LineEffect.VertexShader);
			LineGeometry.SetVertexLayout(layout..ReleaseRefNoDelete());
		}
		
		private static GeometryBinding s_quadGeometry ~ _?.ReleaseRef();

		static void InitDeferredRenderer(EffectLibrary effectLibrary)
		{
			TestFullscreenEffect = effectLibrary.Load("content\\Shaders\\simpleLight.hlsl");

			s_quadGeometry = new GeometryBinding();
			s_quadGeometry.SetPrimitiveTopology(.TriangleList);

			using(var quadVertices = new VertexBuffer(typeof(Vector4), 4, .Immutable))
			{
				Vector4[4] vertices = .(
					.(-0.5f,-0.5f, 0, 1),
					.(-0.5f, 0.5f, 0, 0),
					.( 0.5f, 0.5f, 1, 0),
					.( 0.5f,-0.5f, 1, 1)
					);

				quadVertices.SetData(vertices);
				s_quadGeometry.SetVertexBufferSlot(quadVertices, 0);
			}

			using(var quadIndices = new IndexBuffer(6, .Immutable))
			{
				uint16[6] indices = .(
						0, 1, 2,
						2, 3, 0
					);

				quadIndices.SetData(indices);
				s_quadGeometry.SetIndexBuffer(quadIndices);
			}

			VertexElement[] vertexElements = new .(
				VertexElement(.R32G32_Float, "POSITION", false, 0, 0, 0, .PerVertexData, 0),
				VertexElement(.R32G32_Float, "TEXCOORD", false, 0, 0, (.)-1, .PerVertexData, 0)
			);

			using (var quadBatchLayout = new VertexLayout(vertexElements, true, TestFullscreenEffect.VertexShader))
			{
				s_quadGeometry.SetVertexLayout(quadBatchLayout);
			}
		}

		// TODO
		/*public static void BeginScene(EcsWorld world, EcsEntity cameraEntity)
		{
			Debug.Profiler.ProfileRendererFunction!();

			var camera = world.GetComponent<CameraComponent>(cameraEntity);
			var transform = world.GetComponent<TransformComponent>(cameraEntity);

			var trans = transform.WorldTransform;
			var view = trans.Invert();
			var proj = camera.Projection;

			_sceneConstants.ViewProjection = proj * view;
		}*/

		public static void BeginScene(OldCamera camera)
		{
			Debug.Profiler.ProfileRendererFunction!();

			_sceneConstants.ViewProjection = camera.ViewProjection;
			//_sceneConstants.Data.ViewProjection = camera.ViewProjection;
			//_sceneConstants.Update();
		}

		public static void BeginScene(Camera camera, Matrix transform, RenderTarget2D renderTarget)
		{
			Debug.Profiler.ProfileRendererFunction!();
			
			Matrix viewProjection = camera.Projection * Matrix.Invert(transform);
			_sceneConstants.ViewProjection = viewProjection;
			_sceneConstants.CameraPosition = transform.Translation;
			_sceneConstants.CameraTarget = renderTarget;
		}

		public static int SortMeshes(SubmittedMesh left, SubmittedMesh right)
		{
			// TODO: Once Material "inheritance" is ready we could perhaps check how similar materials are (e.g. shared textures/variables/etc...)
			// Similar thing could be done for Meshes. Both would probably require a different way to sort howerver?...

			int cmp = (int)Internal.UnsafeCastToPtr(left.Material) <=> (int)Internal.UnsafeCastToPtr(right.Material);

			// Material equal: Sort by Mesh
			if (cmp == 0)
			{
				cmp = (int)Internal.UnsafeCastToPtr(left.Mesh) <=> (int)Internal.UnsafeCastToPtr(right.Mesh);

				// Material and Mesh equal: sort by distance
				if (cmp == 0)
				{
					float distLeftSq = Vector3.DistanceSquared(_sceneConstants.CameraPosition, left.Transform.Translation);
					float distRightSq = Vector3.DistanceSquared(_sceneConstants.CameraPosition, right.Transform.Translation);

					// Whether or not the values are squared doesn't affect the order (because square(-root) is a monotonic function)
					cmp = distLeftSq <=> distRightSq;
				}
			}

			return 0;
		}

		public static void EndScene()
		{
			Debug.Profiler.ProfileRendererFunction!();

			_queue.Sort(scope => SortMeshes);

			// Deferred renderer:

			// TODO: foreach light: draw shadow map
			
			// foreach camera:
			// {
			_gBuffer.EnsureSize(_sceneConstants.CameraTarget.Width, _sceneConstants.CameraTarget.Height);
			_gBuffer.Bind();
			RenderCommand.Clear(_gBuffer.Color, .Color | .Depth, .Blue, 1, 0);
			RenderCommand.Clear(_gBuffer.Normal, Color.Beige);
			RenderCommand.Clear(_gBuffer.Position, Color.Black);
			
			/*RenderCommand.UnbindRenderTargets();
			RenderCommand.SetRenderTarget(_sceneConstants.CameraTarget, 0, true);
			RenderCommand.BindRenderTargets();*/

			// TODO: Draw into GBuffer
			for (SubmittedMesh entry in _queue)
			{
				entry.Material.SetVariable("ViewProjection", _sceneConstants.ViewProjection);
				entry.Material.SetVariable("Transform", entry.Transform);
	
				entry.Material.Bind(_context);
	
				entry.Mesh.Bind();
				RenderCommand.DrawIndexed(entry.Mesh);
			}
			
			RenderCommand.UnbindRenderTargets();
			RenderCommand.SetRenderTarget(_sceneConstants.CameraTarget, 0, true);
			RenderCommand.BindRenderTargets();

			_gBuffer.Color.SamplerState = SamplerStateManager.PointClamp;

			TestFullscreenEffect.SetTexture("Colors", _gBuffer.Color);
			TestFullscreenEffect.SetTexture("Normals", _gBuffer.Normal);
			//TestFullscreenEffect.SetTexture("Positions", _gBuffer.Position);

			//TestFullscreenEffect.SetVariable("LightDir");

			TestFullscreenEffect.Bind(_context);

			s_quadGeometry.Bind();
			RenderCommand.DrawIndexed(s_quadGeometry);

			// TODO: Draw lights to camera target
			// }

			// Queue entries increase the reference counter of the mesh/material thus we have to dispose of them.
			ClearAndDisposeItems!(_queue);
		}

		public static void Submit(GeometryBinding geometry, Effect effect, Matrix transform = .Identity)
		{
			Debug.Profiler.ProfileRendererFunction!();

			//effect.PixelShader?.Buffers.TryReplaceBuffer("SceneConstants", _sceneConstants);
			//effect.VertexShader?.Buffers.TryReplaceBuffer("SceneConstants", _sceneConstants);

			//_objectConstants.Data.Transform = transform;
			//_objectConstants.Update();

			//effect.PixelShader?.Buffers.TryReplaceBuffer("ObjectConstants", _objectConstants);
			//effect.VertexShader?.Buffers.TryReplaceBuffer("ObjectConstants", _objectConstants);
			
			effect.Variables["ViewProjection"].SetData(_sceneConstants.ViewProjection);
			effect.Variables["Transform"].SetData(transform);

			effect.Bind(_context);

			geometry.Bind();
			RenderCommand.DrawIndexed(geometry);
		}

		struct SubmittedMesh : IDisposable
		{
			public GeometryBinding Mesh;
			public Material Material;
			public Matrix Transform;

			public this(GeometryBinding mesh, Material material, Matrix transform)
			{
				Mesh = mesh..AddRef();
				Material = material..AddRef();
				Transform = transform;
			}

			public void Dispose()
			{
				Mesh.ReleaseRef();
				Material.ReleaseRef();
			}
		}

		private static List<SubmittedMesh> _queue = new .(10000) ~ DeleteContainerAndDisposeItems!(_);

		public static void Submit(GeometryBinding geometry, Material material, Matrix transform = .Identity)
		{
			Debug.Profiler.ProfileRendererFunction!();

			_queue.Add(SubmittedMesh(geometry, material, transform));
		}

		/** @brief Draws a line.
		 * @param start The start point of the line.
		 * @param end The end point of the line.
		 * @param color The color of the line.
		 */
		public static void DrawLine(Vector3 start, Vector3 end, Color color)
		{
			DrawLine(Vector4(start, 1.0f), Vector4(end, 1.0f), color, .Identity);
		}
		
		/** @brief Draws a line.
		 * @param start The start point of the line.
		 * @param end The end point of the line.
		 * @param color The color of the line.
		 * @param transform A transform matrix transforming the line.
		 */
		public static void DrawLine(Vector3 start, Vector3 end, Color color, Matrix transform)
		{
			DrawLine(Vector4(start, 1.0f), Vector4(end, 1.0f), color, transform);
		}
		
		/** @brief Draws a ray.
		 * @param start The start point of the ray.
		 * @param direction The direction of the ray.
		 * @param color The color of the ray.
		 */
		public static void DrawRay(Vector3 start, Vector3 direction, Color color)
		{
			DrawLine(Vector4(start, 1.0f), Vector4(direction, 0.0f), color, .Identity);
		}

		/** @brief Draws a ray.
		 * @param start The start point of the ray.
		 * @param direction The direction of the ray.
		 * @param color The color of the ray.
		 * @param transform A transform matrix transforming the ray.
		 */
		public static void DrawRay(Vector3 start, Vector3 direction, Color color, Matrix transform)
		{
			DrawLine(Vector4(start, 1.0f), Vector4(direction, 0.0f), color, transform);
		}
		
		/** @brief Draws a line.
		 * @param start The start point of the line.
		 * @param end The end point of the line.
		 * @param color The color of the line.
		 * @param transform A transform matrix transforming the line.
		 */
		public static void DrawLine(Vector4 start, Vector4 end, Color color, Matrix transform)
		{
			Debug.Profiler.ProfileRendererFunction!();

			LineVertices.SetData(Vector4[2](start, end), 0, .WriteDiscard);
			LineEffect.Variables["ViewProjection"].SetData(_sceneConstants.ViewProjection * transform);
			LineEffect.Variables["Color"].SetData(color);

			LineEffect.Bind(_context);

			LineGeometry.Bind();
			RenderCommand.DrawIndexed(LineGeometry);
		}
	}
}
