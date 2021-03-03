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
		public Int32_2 XX => Int32_2((int32)this);

		[Inline]
		public Int32_3 XXX => Int32_3((int32)this);

		[Inline]
		public Int32_4 XXXX => Int32_4((int32)this);
	}
}
