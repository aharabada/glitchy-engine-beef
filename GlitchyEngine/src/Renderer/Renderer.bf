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

		static GraphicsContext _context ~ _?.ReleaseRef();

		//static Buffer<SceneConstants> _sceneConstants ~ _?.ReleaseRef();

		//static Buffer<ObjectConstants> _objectConstants ~ _?.ReleaseRef();

		static SceneConstants _sceneConstants;

		public static void Init(GraphicsContext context)
		{
			_context = context..AddRef();
			/*
			_sceneConstants = new Buffer<SceneConstants>(_context, .(0, .Constant, .Dynamic, .Write));
			_sceneConstants.Update();

			_objectConstants = new Buffer<ObjectConstants>(_context, .(0, .Constant, .Dynamic, .Write));
			_objectConstants.Update();
			*/

			RenderCommand.Init();
		}

		public static void BeginScene(EcsWorld world, Entity cameraEntity)
		{
			var camera = world.GetComponent<CameraComponent>(cameraEntity);
			var transform = world.GetComponent<TransformComponent>(cameraEntity);

			var trans = transform.Transform;
			var view = trans.Invert();
			var proj = camera.Projection;

			_sceneConstants.ViewProjection = proj * view;
		}

		public static void BeginScene(Camera camera)
		{
			_sceneConstants.ViewProjection = camera.ViewProjection;
			//_sceneConstants.Data.ViewProjection = camera.ViewProjection;
			//_sceneConstants.Update();
		}

		public static void EndScene(){}

		public static void Submit(GeometryBinding geometry, Effect effect, Matrix transform = .Identity)
		{
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
	}
}
