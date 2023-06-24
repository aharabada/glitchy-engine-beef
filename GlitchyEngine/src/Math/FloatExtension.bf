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
		public float2 XX => (float2)this;
		
		[Inline]
		public float3 XXX => (float3)this;
		
		[Inline]
		public float4 XXXX => (float4)this;
	}
}
