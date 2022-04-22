using System;
using System.Interop;

namespace GlitchyEngineHelper
{
	static class DotNetRuntime
	{
		[LinkName("TestRunDotNet"), CallingConvention(.Cdecl)]
		public static extern c_int TestRunDotNet(c_int argc, c_wchar** argv);

		[LinkName("DotNet_Init"), CallingConvention(.Cdecl)]
		public static extern c_int Init();

		[LinkName("DotNet_Deinit"), CallingConvention(.Cdecl)]
		public static extern c_int Deinit();

		[LinkName("DotNet_LoadRuntime"), CallingConvention(.Cdecl)]
#if BF_PLATFORM_WINDOWS
		private static extern void Internal_LoadRuntime(char16* configPath);
#else
		private static extern void Internal_LoadRuntime(char8* configPath);
#endif

		public static void LoadRuntime(StringView configPath)
		{
#if BF_PLATFORM_WINDOWS
			Internal_LoadRuntime(configPath.ToScopedNativeWChar!());
#else
			Internal_LoadRuntime(configPath.Ptr);
#endif
		}
		
		[LinkName("DotNet_LoadAssemblyAndGetFunctionPointer"), CallingConvention(.Cdecl)]
#if BF_PLATFORM_WINDOWS
		private static extern c_int DotNet_LoadAssemblyAndGetFunctionPointer(char16* assemblyPath, char16* typeName, char16* methodName, char16* delegateName, void** outDelegate);
#else
		private static extern c_int DotNet_LoadAssemblyAndGetFunctionPointer(char8* assemblyPath, char8* typeName, char8* methodName, char8* delegateName, void** outDelegate);
#endif

		public typealias ManagedDelegate = function int32(void *arg, int32 arg_size_in_bytes);

		public static c_int LoadAssemblyAndGetFunctionPointer(StringView assemblyPath, StringView typeName, StringView methodName, out ManagedDelegate outDelegate)
 		{
			 outDelegate = ?;

#if BF_PLATFORM_WINDOWS
			return DotNet_LoadAssemblyAndGetFunctionPointer(assemblyPath.ToScopedNativeWChar!(), typeName.ToScopedNativeWChar!(), methodName.ToScopedNativeWChar!(), null, (void**)&outDelegate);
#else

#endif
		}

		public static c_int LoadAssemblyAndGetFunctionPointer<T>(StringView assemblyPath, StringView typeName, StringView methodName, StringView delegateName, out T outDelegate) where T : var
 		{
			 outDelegate = ?;

#if BF_PLATFORM_WINDOWS
			return DotNet_LoadAssemblyAndGetFunctionPointer(assemblyPath.ToScopedNativeWChar!(), typeName.ToScopedNativeWChar!(), methodName.ToScopedNativeWChar!(), delegateName.ToScopedNativeWChar!(), (void**)&outDelegate);
#else

#endif
		}

		public static c_int LoadAssemblyAndGetFunctionPointer<T>(StringView assemblyPath, StringView typeName, StringView methodName, out T outDelegate) where T : var
 		{
			 outDelegate = ?;

#if BF_PLATFORM_WINDOWS
			return DotNet_LoadAssemblyAndGetFunctionPointer(assemblyPath.ToScopedNativeWChar!(), typeName.ToScopedNativeWChar!(), methodName.ToScopedNativeWChar!(), (char16*)(void*)-1, (void**)&outDelegate);
#else

#endif
		}
	}
}