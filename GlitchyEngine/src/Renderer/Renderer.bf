using GlitchyEngine.Math;
using GlitchyEngine.World;

namespace GlitchyEngine.Renderer
{
	public class Renderer
	{
		struct SceneConstants
		{
			public Matrix ViewProjection;
		}

		struct ObjectConstants
		{
			public Matrix Transform;
		}

		static internal GraphicsContext _context ~ _?.ReleaseRef();

		//static Buffer<SceneConstants> _sceneConstants ~ _?.ReleaseRef();

		//static Buffer<ObjectConstants> _objectConstants ~ _?.ReleaseRef();

		static SceneConstants _sceneConstants;

		static Effect LineEffect ~ _?.ReleaseRef();
		static VertexBuffer LineVertices ~ _?.ReleaseRef();
		static GeometryBinding LineGeometry ~ _?.ReleaseRef();

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

		public static void BeginScene(EcsWorld world, EcsEntity cameraEntity)
		{
			Debug.Profiler.ProfileRendererFunction!();

			var camera = world.GetComponent<CameraComponent>(cameraEntity);
			var transform = world.GetComponent<TransformComponent>(cameraEntity);

			var trans = transform.WorldTransform;
			var view = trans.Invert();
			var proj = camera.Projection;

			_sceneConstants.ViewProjection = proj * view;
		}

		public static void BeginScene(Camera camera)
		{
			Debug.Profiler.ProfileRendererFunction!();

			_sceneConstants.ViewProjection = camera.ViewProjection;
			//_sceneConstants.Data.ViewProjection = camera.ViewProjection;
			//_sceneConstants.Update();
		}

		public static void EndScene()
		{
			Debug.Profiler.ProfileRendererFunction!();
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

		public static void Submit(GeometryBinding geometry, Material material, Matrix transform = .Identity)
		{
			Debug.Profiler.ProfileRendererFunction!();

			material.SetVariable("ViewProjection", _sceneConstants.ViewProjection);
			material.SetVariable("Transform", transform);

			material.Bind(_context);

			geometry.Bind();
			RenderCommand.DrawIndexed(geometry);
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
