using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer
{
	public class Renderer
	{
		struct SceneConstants
		{
			public Matrix ViewProjection;
		}

		static GraphicsContext _context;

		static Buffer<SceneConstants> _sceneConstants ~ delete _;

		public static void Init(GraphicsContext context)
		{
			_context = context;
			_sceneConstants = new Buffer<SceneConstants>(_context, .(0, .Constant, .Dynamic, .Write));
			_sceneConstants.Update();
		}

		public static void BeginScene(Camera camera)
		{
			_sceneConstants.Data.ViewProjection = camera.ViewProjection;
			_sceneConstants.Update();
		}

		public static void EndScene(){}

		public static void Submit(GeometryBinding geometry, Effect effect)
		{
			effect.Bind(_context);

			effect.PixelShader?.Buffers.TryReplaceBuffer("SceneConstants", _sceneConstants);
			effect.VertexShader?.Buffers.TryReplaceBuffer("SceneConstants", _sceneConstants);

			geometry.Bind();
			RenderCommand.DrawIndexed(geometry);
		}
	}
}
