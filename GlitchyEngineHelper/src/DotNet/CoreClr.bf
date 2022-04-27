using System;
using System.Interop;

using internal GlitchyEngineHelper.DotNet;

namespace GlitchyEngineHelper.DotNet
{
	static
	{
#if BF_PLATFORM_WINDOWS
		internal typealias char = char16;
#else
		internal typealias char = char8;
#endif
	}

	static class CoreClr
	{
		public const char* UNMANAGEDCALLERSONLY_METHOD = (char*)(void*)-1;

		public typealias LoadAssemblyAndGetFunctionPointerFn = function [CallingConvention(.Stdcall)] c_int(
			char* assemblyPath,
    		char* typeName,
    		char* methodName,
    		char* delegateTypeName,
    		void* reserved,
    		out void* outDelegate);

		public typealias GetFunctionPointerFn = function [CallingConvention(.Stdcall)] c_int(
			char* typeName,
			char* MethodName,
			char* delegateTypeName,
			void* loadContext,
			void* reserved,
			out void* outDelegate
			);
	}
}