using System;
using System.IO;
using System.Interop;
using System.Diagnostics;

using internal GlitchyEngineHelper.DotNet;

namespace GlitchyEngineHelper
{
	class DotNet
	{
#if BF_PLATFORM_WINDOWS
		internal typealias char = char16;
#else
		internal typealias char = char8;
#endif

		HostFxr.Handle cxt = null;
		
		HostFxr.InitializeForDotnetCommandLineFn InitFn;
		HostFxr.GetRuntimeDelegateFn GetDelegate;
		HostFxr.CloseFn Close;
		HostFxr.SetRuntimePropertyValueFn SetRuntimePropertyValueFn;

		CoreClr.LoadAssemblyAndGetFunctionPointerFn LoadAssemblyAndGetFunctionPointerFn;
		CoreClr.GetFunctionPointerFn GetFunctionPointerFn;
		
		private const char* UNMANAGEDCALLERSONLY_METHOD = (char*)(void*)-1;

		private String _configPath ~ delete _;

		public this(String configPath)
		{
			_configPath = new String(configPath);
		}

		private mixin RawPointer(StringView str)
		{
#if BF_PLATFORM_WINDOWS
			str.ToScopedNativeWChar!:mixin()
#else
			str.CStr()
#endif
		}

		public void Init()
		{
			LoadHostFxr();

			InitAndStartRuntime();
		}

		private void LoadHostFxr()
 		{
			 char[256] buffer = ?;
			 c_size bufferSize = buffer.Count;
			 int rc = NetHost.get_hostfxr_path(&buffer, &bufferSize, null);

			 Debug.Assert(rc == 0);

			// Load hostfxr and get desired exports
			void* lib = LoadLibrary(&buffer);
			InitFn = GetExport<HostFxr.InitializeForDotnetCommandLineFn>(lib, "hostfxr_initialize_for_dotnet_command_line");
			GetDelegate = GetExport<HostFxr.GetRuntimeDelegateFn>(lib, "hostfxr_get_runtime_delegate");
			SetRuntimePropertyValueFn = GetExport<HostFxr.SetRuntimePropertyValueFn>(lib, "hostfxr_set_runtime_property_value");
			Close = GetExport<HostFxr.CloseFn>(lib, "hostfxr_close");

			Debug.Assert(InitFn != null && GetDelegate != null && Close != null);
		}

		private void InitAndStartRuntime()
		{
			char* ptr = RawPointer!(_configPath);

			char*[2] args = char*[](
				ptr,
				null
			);

			//int rc = InitFn(ptr, null, &cxt);
			int rc = InitFn(1, &args, null, &cxt);

			if (rc != 0 || cxt == null)
			{
				Debug.WriteLine($"Init failed: {rc}");
			    Close(cxt);
			
				Debug.Assert(rc == 0);

			    return;
			}

			Debug.Assert(rc == 0);

			rc = GetDelegate(cxt, .LoadAssemblyAndGetFunctionPointer, (void**)&LoadAssemblyAndGetFunctionPointerFn);

			Debug.Assert(rc == 0, scope $"Get delegate failed: {rc}");

			rc = GetDelegate(cxt, .GetFunctionPointer, (void**)&GetFunctionPointerFn);

			Debug.Assert(rc == 0, scope $"Get delegate failed: {rc}");

			Close(cxt);
		}

		public int SetRuntimePropertyValue(StringView property, StringView value)
		{
			return SetRuntimePropertyValueFn(cxt, RawPointer!(property), RawPointer!(value));
		}

		public int LoadAssemblyAndGetFunctionPointer<T>(String libraryPath, String typeName, String methodName, String delegateName, out T outDelegate) where T: operator explicit void*
		{
			void* funPtr = null;

#if BF_PLATFORM_WINDOWS
			int rc = LoadAssemblyAndGetFunctionPointerFn(libraryPath.ToScopedNativeWChar!(), typeName.ToScopedNativeWChar!(), methodName.ToScopedNativeWChar!(), delegateName.ToScopedNativeWChar!(), null, out funPtr);
#endif

			outDelegate = (T)funPtr;

			return rc;
		}

		public int LoadAssemblyAndGetFunctionPointerUnmanagedCallersOnly<T>(String libraryPath, String typeName, String methodName, out T outDelegate) where T: operator explicit void*
		{
			void* funPtr = null;

#if BF_PLATFORM_WINDOWS
			int rc = LoadAssemblyAndGetFunctionPointerFn(libraryPath.ToScopedNativeWChar!(), typeName.ToScopedNativeWChar!(), methodName.ToScopedNativeWChar!(), UNMANAGEDCALLERSONLY_METHOD, null, out funPtr);
#endif

			outDelegate = (T)funPtr;

			return rc;
		}

		public int GetFunctionPointer<T>(String typeName, String methodName, String delegateName, out T outDelegate) where T: operator explicit void*
		{
			void* funPtr = null;

#if BF_PLATFORM_WINDOWS
			int rc = GetFunctionPointerFn(typeName.ToScopedNativeWChar!(), methodName.ToScopedNativeWChar!(), delegateName.ToScopedNativeWChar!(), null, null, out funPtr);
#endif

			outDelegate = (T)funPtr;

			return rc;
		}

		public int GetFunctionPointerUnmanagedCallersOnly<T>(String typeName, String methodName, out T outDelegate) where T: operator explicit void*
		{
			void* funPtr = null;

#if BF_PLATFORM_WINDOWS
			int rc = GetFunctionPointerFn(typeName.ToScopedNativeWChar!(), methodName.ToScopedNativeWChar!(), UNMANAGEDCALLERSONLY_METHOD, null, null, out funPtr);
#endif

			outDelegate = (T)funPtr;

			return rc;
		}
		
#if BF_PLATFORM_WINDOWS
		private void* LoadLibrary(char* path)
		{
			Windows.HInstance handle = Windows.LoadLibraryW(path);

			Debug.Assert(handle != 0);

			return (void*)(int)handle;
		}

	    private T GetExport<T>(void* handle, char8* name) where T : operator explicit void*
	    {
	        void* f = Windows.GetProcAddress((Windows.HModule)(int)handle, name);
			
			Debug.Assert(f != null);

	        return (T)f;
	    }
#else
		private void* LoadLibrary(char* path)
		{
			// TODO!
		}
#endif
	}

	static class HostFxr
	{
#if BF_PLATFORM_WINDOWS
		internal typealias char = char16;
#else
		internal typealias char = char8;
#endif

		public enum DelegateType : c_int
		{
		    ComActivation,
		    LoadInMemoryAssembly,
		    WinrtActivation,
		    ComRegister,
		    ComUnregister,
		    LoadAssemblyAndGetFunctionPointer,
		    GetFunctionPointer,
		}
		
		public typealias Handle = void*;

		[CRepr]
		public struct InitializeParameters
		{
		    public c_size Size = sizeof(InitializeParameters);
		    public char* HostPath;
		    public char* DotnetRoot;
		};

		public typealias InitializeForRuntimeConfigFn = function [CallingConvention(.Cdecl)] int32(char* runtimeConfigPath, InitializeParameters* parameters, Handle* hostContextHandle);
		public typealias InitializeForDotnetCommandLineFn = function [CallingConvention(.Cdecl)] int32(c_int argc, char** argv, InitializeParameters* parameters, Handle* hostContextHandle);
		public typealias GetRuntimeDelegateFn = function [CallingConvention(.Cdecl)] int32(Handle host_context_handle, DelegateType type, void** outDelegate);
		public typealias SetRuntimePropertyValueFn = function [CallingConvention(.Cdecl)] int32(Handle host_context_handle, char* name, char* value);
		public typealias CloseFn = function [CallingConvention(.Cdecl)] int32(Handle host_context_handle);
	}

	static class CoreClr
	{
#if BF_PLATFORM_WINDOWS
		internal typealias char = char16;
#else
		internal typealias char = char8;
#endif

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

	static class NetHost
	{
		public struct get_hostfxr_parameters
		{
		    public c_size size;
		    public DotNet.char* assembly_path;
		    public DotNet.char* dotnet_root;
		};

		[CallingConvention(.Stdcall), LinkName("get_hostfxr_path")]
		public static extern int get_hostfxr_path(
			DotNet.char * buffer,
			c_size * buffer_size,
			get_hostfxr_parameters *parameters);
	}
}