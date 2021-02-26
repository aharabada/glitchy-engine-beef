namespace GlitchyEngine.Math
{
	struct Ray
	{
		public Vector3 Start;
		public Vector3 Direction;

		public this() => this = default;

		public this(Vector3 start, Vector3 direction)
		{
			Start = start;
			Direction = direction;
		}
	}
}
