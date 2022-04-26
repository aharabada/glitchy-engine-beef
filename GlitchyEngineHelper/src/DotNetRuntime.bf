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

#if BF_PLATFORM_WINDOWS
		private typealias char_t = char16;
#else
		private typealias char_t = char8;
#endif

		[LinkName("DotNet_LoadRuntime"), CallingConvention(.Cdecl)]
		private static extern void Internal_LoadRuntime(char_t* configPath);

		private static char_t* UNMANAGEDCALLERSONLY_METHOD = (char_t*)(void*)-1;

		public static void LoadRuntime(StringView configPath)
		{
#if BF_PLATFORM_WINDOWS
			Internal_LoadRuntime(configPath.ToScopedNativeWChar!());
#else
			Internal_LoadRuntime(configPath.Ptr);
#endif
		}
		
		[LinkName("DotNet_LoadAssemblyAndGetFunctionPointer"), CallingConvention(.Cdecl)]
		private static extern c_int DotNet_LoadAssemblyAndGetFunctionPointer(char_t* assemblyPath, char_t* typeName, char_t* methodName, char_t* delegateName, void** outDelegate);

		public typealias ManagedDelegate = function int32(void *arg, int32 arg_size_in_bytes);

		public static c_int LoadAssemblyAndGetFunctionPointer<T>(StringView assemblyPath, StringView typeName, StringView methodName, StringView? delegateName, out T outDelegate) where T : var
 		{
			outDelegate = null;

#if BF_PLATFORM_WINDOWS
			return DotNet_LoadAssemblyAndGetFunctionPointer(assemblyPath.ToScopedNativeWChar!(), typeName.ToScopedNativeWChar!(), methodName.ToScopedNativeWChar!(), delegateName?.ToScopedNativeWChar!(), (void**)&outDelegate);
#else
			Runtime.NotImplemented();
#endif
		}

		public static c_int LoadAssemblyAndGetFunctionPointer(StringView assemblyPath, StringView typeName, StringView methodName, out ManagedDelegate outDelegate)
 		{
			 return LoadAssemblyAndGetFunctionPointer<ManagedDelegate>(assemblyPath, typeName, methodName, null, out outDelegate);
		}

		public static c_int LoadAssemblyAndGetFunctionPointerUnmanagedCallersOnly<T>(StringView assemblyPath, StringView typeName, StringView methodName, out T outDelegate) where T : var
 		{
			outDelegate = null;

#if BF_PLATFORM_WINDOWS
			return DotNet_LoadAssemblyAndGetFunctionPointer(assemblyPath.ToScopedNativeWChar!(), typeName.ToScopedNativeWChar!(), methodName.ToScopedNativeWChar!(), UNMANAGEDCALLERSONLY_METHOD, (void**)&outDelegate);
#else
			Runtime.NotImplemented();
#endif
		}



		[LinkName("DotNet_GetFunctionPointer"), CallingConvention(.Cdecl)]
		private static extern c_int DotNet_GetFunctionPointer(char_t* typeName, char_t* methodName, char_t* delegateName, void** outDelegate);
		
		public static c_int GetFunctionPointer<T>(StringView typeName, StringView methodName, StringView delegateName, out T outDelegate) where T : var
		{
			 outDelegate = null;

#if BF_PLATFORM_WINDOWS
			return DotNet_GetFunctionPointer(typeName.ToScopedNativeWChar!(), methodName.ToScopedNativeWChar!(), delegateName.ToScopedNativeWChar!(), (void**)&outDelegate);
#else
			Runtime.NotImplemented();
#endif
		}

		public static c_int GetFunctionPointer(StringView typeName, StringView methodName, out ManagedDelegate outDelegate)
		{
			return GetFunctionPointer<ManagedDelegate>(typeName, methodName, null, out outDelegate);
		}

		public static c_int GetFunctionPointerUnmanagedCallersOnly<T>(StringView typeName, StringView methodName, out T outDelegate) where T : var
		{
			 outDelegate = null;

#if BF_PLATFORM_WINDOWS
			return DotNet_GetFunctionPointer(typeName.ToScopedNativeWChar!(), methodName.ToScopedNativeWChar!(), UNMANAGEDCALLERSONLY_METHOD, (void**)&outDelegate);
#else
			Runtime.NotImplemented();
#endif
		}
	}
}