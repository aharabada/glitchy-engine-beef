using GlitchyEngine.Math;

namespace GlitchyEngine.World
{
	public struct TransformComponent
	{
		static int _id;

		public static int ID {get => _id; set => _id = value; }

		internal Matrix _transform;

		public Matrix Transform
		{
			get => _transform;
			set mut => _transform = value;
		}
	}
}
