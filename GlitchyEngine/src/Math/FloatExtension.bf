using GlitchyEngine.Math;

namespace System
{
	extension Float
	{
		public float X
		{
			[Inline]
			get => (float)this;
			[Inline]
			set mut => this = value;
		}

		[Inline]
		public Vector2 XX => Vector2((float)this);
		
		[Inline]
		public Vector3 XXX => Vector3((float)this);
		
		[Inline]
		public Vector4 XXXX => Vector4((float)this);
	}
}
