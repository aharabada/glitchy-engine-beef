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
		public int2 XX => (int32)this;

		[Inline]
		public int3 XXX => (int32)this;

		[Inline]
		public int4 XXXX => (int32)this;
	}

	extension UInt32
	{
		public uint32 X
		{
			[Inline]
			get => (uint32)this;
			[Inline]
			set mut => this = value;
		}

		[Inline]
		public uint2 XX => (uint32)this;

		[Inline]
		public uint3 XXX => (uint32)this;

		[Inline]
		public uint4 XXXX => (uint32)this;
	}
}
