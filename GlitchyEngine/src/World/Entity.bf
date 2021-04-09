using System;

using internal GlitchyEngine.World;

namespace GlitchyEngine.World
{
	public struct Entity : uint64
	{	
		// Binary Format:
		// Bits: [0 - 31] [32 - 64]
		// Data: Version    Index

		[Inline]
		internal uint32 Version => (uint32)this;

		[Inline]
		internal uint32 Index => (uint32)(this >> 32);
		
		[Inline]
		static internal Entity CreateEntityID(uint32 index, uint32 version)
		{
			return ((uint64)index << 32) | version;
		}
		
		[Inline]
		internal bool IsValid => Index != InvalidEntity.Index;

		public const Entity InvalidEntity = ((uint64)uint32.MaxValue << 32) | 0;//TODO: Report bug: CreateEntityID(uint32.MaxValue, 0);
	}
}
