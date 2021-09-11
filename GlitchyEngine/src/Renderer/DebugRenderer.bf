using GlitchyEngine.Math;
using GlitchyEngine.World;

namespace GlitchyEngine.Renderer
{
	/// Provides functionality for debugging
	public static class DebugRenderer
	{
		private static GeometryBinding CoordinateCross;

		public static void Init(GraphicsContext context)
		{
			CreateCoordinateCross(context);
		}

		private static void CreateCoordinateCross(GraphicsContext context)
		{
			CoordinateCross = new GeometryBinding(context);
			//CoordinateCross.PrimitiveTopology
		}

		public static void Deinit()
		{
			CoordinateCross.ReleaseRef();
		}

		public static bool DrawEntityTransforms = true;

		public static void Render(EcsWorld world)
		{
			if(DrawEntityTransforms)
			{
				for(var (entity, transform) in world.Enumerate<TransformComponent>())
				{
					Renderer.DrawLine(.Zero, Vector3(1f, 0, 0), .Red,  transform.WorldTransform);
					Renderer.DrawLine(.Zero, Vector3(0, 1f, 0), .Lime, transform.WorldTransform);
					Renderer.DrawLine(.Zero, Vector3(0, 0, 1f), .Blue, transform.WorldTransform);
				}
			}
		}
	}
}
