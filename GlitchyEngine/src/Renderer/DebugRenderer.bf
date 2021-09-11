using GlitchyEngine.Math;
using GlitchyEngine.World;

namespace GlitchyEngine.Renderer
{
	/// Provides functionality for debugging
	public static class DebugRenderer
	{
		private static GeometryBinding CoordinateCross;
		
		public static bool DrawEntityTransforms = true;

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

		/**
		 * Draws a coordinate cross for the given matrix.
		 * @param transform The transform matrix.
		 * @param length Can be used to set a fixed length for the rendered lines that represent the axes.
		 * 		 Set to 0 if you want transform to affect the length of the lines.
		 */
		public static void DrawCoordinateCross(Matrix transform, float length = 0.0f)
		{
			var transform;

			if(length != 0.0f)
			{
				transform.Columns[0]..Normalize() *= length;
				transform.Columns[1]..Normalize() *= length;
				transform.Columns[2]..Normalize() *= length;
			}

			Renderer.DrawLine(.Zero, .Right,   .Red,  transform);
			Renderer.DrawLine(.Zero, .Up,      .Lime, transform);
			Renderer.DrawLine(.Zero, .Forward, .Blue, transform);
		}

		public static void Render(EcsWorld world)
		{
			if(DrawEntityTransforms)
			{
				for(var (entity, transform) in world.Enumerate<TransformComponent>())
				{
					DrawCoordinateCross(transform.WorldTransform);
				}
			}
		}
	}
}
