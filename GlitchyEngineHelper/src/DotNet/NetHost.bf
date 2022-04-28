using System;
using System.Interop;

using internal GlitchyEngineHelper.DotNet;

namespace GlitchyEngineHelper.DotNet
{
	static class NetHost
	{
		public struct get_hostfxr_parameters
		{
		    public c_size size;
		    public char* assembly_path;
		    public char* dotnet_root;
		};

		[CallingConvention(.Stdcall), LinkName("get_hostfxr_path")]
		public static extern int get_hostfxr_path(
			char* buffer,
			c_size* buffer_size,
			get_hostfxr_parameters *parameters);
	}
}