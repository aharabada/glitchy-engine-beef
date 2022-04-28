using System;
using System.IO;
using System.Interop;
using System.Diagnostics;
using GlitchyEngineHelper.DotNet;

namespace GlitchyEngineHelper.DotNet
{
	class DotNetContext
	{
#if BF_PLATFORM_WINDOWS
		internal typealias char = char16;
#else
		internal typealias char = char8;
#endif
		
		HostFxr.InitializeForDotnetCommandLineFn InitFn;
		HostFxr.GetRuntimeDelegateFn GetDelegate;
		HostFxr.CloseFn Close;
		HostFxr.SetRuntimePropertyValueFn SetRuntimePropertyValueFn;

		CoreClr.LoadAssemblyAndGetFunctionPointerFn LoadAssemblyAndGetFunctionPointerFn;
		CoreClr.GetFunctionPointerFn GetFunctionPointerFn;
		
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

			HostFxr.Handle cxt = null;

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

		/*public int SetRuntimePropertyValue(StringView property, StringView value)
		{
			return SetRuntimePropertyValueFn(cxt, RawPointer!(property), RawPointer!(value));
		}*/

		public int LoadAssemblyAndGetFunctionPointer<T>(StringView libraryPath, StringView typeName, StringView methodName, StringView delegateName, out T outDelegate) where T: operator explicit void*
		{
			void* funPtr = null;

			int rc = LoadAssemblyAndGetFunctionPointerFn(RawPointer!(libraryPath), RawPointer!(typeName), RawPointer!(methodName), RawPointer!(delegateName), null, out funPtr);

			outDelegate = (T)funPtr;

			return rc;
		}

		public int LoadAssemblyAndGetFunctionPointerUnmanagedCallersOnly<T>(String libraryPath, String typeName, String methodName, out T outDelegate) where T: operator explicit void*
		{
			void* funPtr = null;

			int rc = LoadAssemblyAndGetFunctionPointerFn(RawPointer!(libraryPath), RawPointer!(typeName), RawPointer!(methodName), CoreClr.UNMANAGEDCALLERSONLY_METHOD, null, out funPtr);

			outDelegate = (T)funPtr;

			return rc;
		}

		public int GetFunctionPointer<T>(String typeName, String methodName, String delegateName, out T outDelegate) where T: operator explicit void*
		{
			void* funPtr = null;

			int rc = GetFunctionPointerFn(RawPointer!(typeName), RawPointer!(methodName), RawPointer!(delegateName), null, null, out funPtr);

			outDelegate = (T)funPtr;

			return rc;
		}

		public int GetFunctionPointerUnmanagedCallersOnly<T>(String typeName, String methodName, out T outDelegate) where T: operator explicit void*
		{
			void* funPtr = null;

			int rc = GetFunctionPointerFn(RawPointer!(typeName), RawPointer!(methodName), CoreClr.UNMANAGEDCALLERSONLY_METHOD, null, null, out funPtr);

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
}