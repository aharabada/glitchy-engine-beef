namespace GlitchyEngine.Renderer
{
	public struct Viewport
	{
		/// X position of the left hand side of the viewport.
		public float Left;
		/// Y position of the top of the viewport. Ranges between BoundsMin and BoundsMax.
		public float Top;
		/// Width of the viewport.
		public float Width;
		/// Height of the viewport.
		public float Height;
		/// Minimum depth of the viewport. Ranges between 0 and 1.
		public float MinDepth;
		/// Maximum depth of the viewport. Ranges between 0 and 1.
		public float MaxDepth;

		public this() => this = default;

		public this(float left, float top, float width, float height, float minDepth = 0.0f, float maxDepth = 1.0f)
		{
			Left = left;
			Top = top;
			Width = width;
			Height = height;
			MinDepth = minDepth;
			MaxDepth = maxDepth;
		}
	}
}
