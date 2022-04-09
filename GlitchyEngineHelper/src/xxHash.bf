using System;
using System.Interop;

namespace xxHash
{
	struct XXH64_hash : uint64{}

	static
	{
		[LinkName(.C)]
		public static extern XXH64_hash XXH64(void* buffer, c_size size, XXH64_hash seed = 0);
	}

	static class xxHash
	{
		[Inline]
		public static XXH64_hash ComputeHash(StringView string, XXH64_hash seed = 0)
		{
			return XXH64(string.Ptr, (.)string.Length, seed);
		}
	}
}