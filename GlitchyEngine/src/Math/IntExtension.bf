using GlitchyEngine.Math;

namespace System
{
	extension Int32
	{
		public int32 X
		{
			[Inline]
			get => (int32)this;
			[Inline]
			set mut => this = value;
		}

		[Inline]
		public Int2 XX => Int2((int32)this);

		[Inline]
		public Int3 XXX => Int3((int32)this);

		[Inline]
		public Int4 XXXX => Int4((int32)this);
	}
}
