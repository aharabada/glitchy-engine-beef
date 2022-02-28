using GlitchyEngine.Math;

namespace GlitchyEngine.World
{
	struct SimpleTransformComponent
	{
		public Matrix Transform = Matrix.Identity;

		public this()
		{

		}	

		public this(Matrix transform)
		{
			Transform = transform;
		}
	}
	
	struct SpriterRendererComponent
	{
		public ColorRGBA Color = .White;

		public this()
		{

		}

		public this(ColorRGBA color)
		{
			Color = color;
		}
	}
}