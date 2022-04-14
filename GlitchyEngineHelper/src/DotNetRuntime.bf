using System;
using System.Interop;
namespace GlitchyEngineHelper
{
	static class DotNetRuntime
	{
		[LinkName("TestRunDotNet"), CallingConvention(.Cdecl)]
		public static extern int TestRunDotNet(c_int argc, c_wchar** argv);

		[LinkName("DotNet_Init"), CallingConvention(.Cdecl)]
		public static extern int Init();
	}
}