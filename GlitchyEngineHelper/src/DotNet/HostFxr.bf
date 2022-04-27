using System;
using System.Interop;

using internal GlitchyEngineHelper.DotNet;

namespace GlitchyEngineHelper.DotNet
{
	static class HostFxr
	{
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
}