using NetHostBeef;
using System;
using System.Interop;
using GlitchyEngine.Core;

namespace GlitchyEngine.Scripting;

public struct ScriptFunctionPointers
{
    public function void() OnCreate;
    public function void(float) OnUpdate;
    public function void() OnDestroy;
}

static class CoreClrHelper
{
	static HostFxr.InitializeForDotnetCommandLineFn HostFxr_Init;
	static HostFxr.GetRuntimeDelegateFn HostFxr_GetDelegate;
	static HostFxr.CloseFn HostFxr_Close;

	static CoreClr.LoadAssemblyAndGetFunctionPointerFn LoadAssemblyAndGetFunctionPointerFn;
	static CoreClr.GetFunctionPointerFn GetFunctionPointerFn;

	private function void LoadScriptAssemblyFunc(uint8* appData, int64 appLength, uint8* pdbData, int64 pdbLength);

	//static function void(char8* path) LoadScriptAssembly;
	static LoadScriptAssemblyFunc _loadScriptAssembly;
	static function void() _unloadAssemblies;

	// public static unsafe void GetScriptClasses(void** outBuffer, long* length)
	private function void GetScriptClassesFunc(void** outBuffer, int64* length);
	static GetScriptClassesFunc _getScriptClasses;
	static function void() _freeScriptClassNames;
	
	//public static unsafe ScriptFunctions CreateScriptInstance(UUID entityId, byte* scriptClassName)
	private function void CreateScriptInstanceFunc(UUID entityId, char8* scriptClassName);
	static CreateScriptInstanceFunc _createScriptInstance;

	public static ScriptFunctionPointers _entityScriptFunctions;

	public static void Init(StringView coreAssemblyPath)
	{
		LoadHostFxr();
		InitAndStartRuntime(coreAssemblyPath);

		PrepareFunction();
	}

	static void LoadHostFxr()
	{
		char_t[256] buffer = ?;
		c_size bufferSize = buffer.Count;
		int rc = NetHost.get_hostfxr_path(&buffer, &bufferSize, null);

		Log.EngineLogger.AssertDebug(rc == 0, "Failed to get HostFxr path.");

		// Load hostfxr and get desired exports
		void* lib = NetHostHelper.LoadLibrary(&buffer);
		HostFxr_Init = NetHostHelper.GetExport<HostFxr.InitializeForDotnetCommandLineFn>(lib, "hostfxr_initialize_for_dotnet_command_line");
		HostFxr_GetDelegate = NetHostHelper.GetExport<HostFxr.GetRuntimeDelegateFn>(lib, "hostfxr_get_runtime_delegate");
		HostFxr_Close = NetHostHelper.GetExport<HostFxr.CloseFn>(lib, "hostfxr_close");

		Log.EngineLogger.AssertDebug(HostFxr_Init != null && HostFxr_GetDelegate != null && HostFxr_Close != null, "Retrieving at least one HostFxr function failed.");
	}

	static void InitAndStartRuntime(StringView coreAssembly)
	{
		char_t* ptr = NetHostHelper.GetScopedRawPtr!(coreAssembly);

		char_t*[2] args = char_t*[](
			ptr,
			null
		);

		HostFxr.Handle cxt = null;
		int rc = HostFxr_Init(1, &args, null, &cxt);

		if (rc != 0 || cxt == null)
		{
			Log.EngineLogger.Error($"Failed to initialize HostFxr: {rc}");
		    HostFxr_Close(cxt);
		}
		
		Log.EngineLogger.Assert(rc == 0, "Failed to initialize HostFxr.");

		rc = HostFxr_GetDelegate(cxt, .LoadAssemblyAndGetFunctionPointer, (void**)&LoadAssemblyAndGetFunctionPointerFn);

		Log.EngineLogger.Assert(rc == 0, scope $"Get delegate failed: {rc}. (LoadAssemblyAndGetFunctionPointer)");

		rc = HostFxr_GetDelegate(cxt, .GetFunctionPointer, (void**)&GetFunctionPointerFn);

		Log.EngineLogger.Assert(rc == 0, scope $"Get delegate failed: {rc}. (GetFunctionPointer)");

		HostFxr_Close(cxt);
	}

	static void PrepareFunction()
	{
		GetFunctionPointerUnmanagedCallersOnly("GlitchyEngine.ScriptGlue, ScriptCore", "LoadScriptAssembly", out _loadScriptAssembly);

		GetFunctionPointerUnmanagedCallersOnly("GlitchyEngine.ScriptGlue, ScriptCore", "UnloadAssemblies", out _unloadAssemblies);
		
		GetFunctionPointerUnmanagedCallersOnly("GlitchyEngine.ScriptGlue, ScriptCore", "GetScriptClasses", out _getScriptClasses);

		GetFunctionPointerUnmanagedCallersOnly("GlitchyEngine.ScriptGlue, ScriptCore", "FreeScriptClassNames", out _freeScriptClassNames);

		GetFunctionPointerUnmanagedCallersOnly("GlitchyEngine.ScriptGlue, ScriptCore", "CreateScriptInstance", out _createScriptInstance);

		InitEntityFunctions();
	}


	static void InitEntityFunctions()
	{
		GetFunctionPointerUnmanagedCallersOnly("GlitchyEngine.ScriptGlue, ScriptCore", "InvokeEntityOnCreate", out _entityScriptFunctions.OnCreate);
		GetFunctionPointerUnmanagedCallersOnly("GlitchyEngine.ScriptGlue, ScriptCore", "InvokeEntityOnUpdate", out _entityScriptFunctions.OnUpdate);
		GetFunctionPointerUnmanagedCallersOnly("GlitchyEngine.ScriptGlue, ScriptCore", "InvokeEntityOnDestroy", out _entityScriptFunctions.OnDestroy);
	}

	public static void LoadAppAssembly(Span<uint8> appAssemblyData, Span<uint8> pdbData)
	{
		_loadScriptAssembly(appAssemblyData.Ptr, appAssemblyData.Length, pdbData.Ptr, pdbData.Length);
	}

	public static void UnloadAssemblies()
	{
		_unloadAssemblies();
	}	

	/// Gets an array of script class infos. Use FreeScriptClassNames to release the buffer.
	public static void GetScriptClasses(out void* outBuffer, out int64 entryCount)
	{
		outBuffer = null;
		entryCount = 0;
		_getScriptClasses(&outBuffer, &entryCount);
	}	

	/// Releases the buffer created by GetScriptClasses
	public static void FreeScriptClassNames()
	{
		_freeScriptClassNames();
	}

	public static void CreateScriptInstance(UUID entityId, StringView scriptName)
	{
		_createScriptInstance(entityId, scriptName.Ptr);
	}

	public static int GetFunctionPointer<T>(StringView typeName, StringView methodName, StringView delegateName, out T outDelegate) where T: operator explicit void*
	{
		void* funPtr = null;

		int rc = GetFunctionPointerFn(NetHostHelper.GetScopedRawPtr!(typeName),
			NetHostHelper.GetScopedRawPtr!(methodName), NetHostHelper.GetScopedRawPtr!(delegateName),
			null, null, out funPtr);

		outDelegate = (T)funPtr;

		return rc;
	}

	public static int GetFunctionPointerDefaultDelegate(StringView typeName, StringView methodName, out CoreClr.DefaultEntryPoint outDelegate)
	{
		void* funPtr = null;

		int rc = GetFunctionPointerFn(NetHostHelper.GetScopedRawPtr!(typeName),
			NetHostHelper.GetScopedRawPtr!(methodName), null, null, null, out funPtr);

		outDelegate = (CoreClr.DefaultEntryPoint)funPtr;

		return rc;
	}

	public static int GetFunctionPointerUnmanagedCallersOnly<T>(StringView typeName, StringView methodName, out T outDelegate) where T: operator explicit void*
	{
		void* funPtr = null;

		int rc = GetFunctionPointerFn(NetHostHelper.GetScopedRawPtr!(typeName),
			NetHostHelper.GetScopedRawPtr!(methodName), CoreClr.UNMANAGEDCALLERSONLY_METHOD, null, null, out funPtr);

		outDelegate = (T)funPtr;

		return rc;
	}
}