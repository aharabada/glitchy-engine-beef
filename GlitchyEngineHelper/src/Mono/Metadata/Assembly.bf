using System;

namespace Mono.Metadata;

class Assembly
{
	[LinkName(.C)]
	public static extern void mono_set_assemblies_path(char8* path);
}