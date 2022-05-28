using System;

using internal GlitchyEngine.World;

namespace GlitchyEngine.World
{
	public struct EcsEntity : uint64
	{	
		// Binary Format:
		// Bits: [0 - 31] [32 - 64]
		// Data: Version    Index

		[Inline]
		public uint32 Version => (uint32)this;

		[Inline]
		public uint32 Index => (uint32)(this >> 32);
		
		[Inline]
		static internal EcsEntity CreateEntityID(uint32 index, uint32 version)
		{
			return ((uint64)index << 32) | version;
		}
		
		[Inline]
		internal bool IsValid => Index != InvalidEntity.Index;

		public const EcsEntity InvalidEntity = CreateEntityID(uint32.MaxValue, 0);
	}
}