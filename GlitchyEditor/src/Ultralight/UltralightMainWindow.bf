using Ultralight.CAPI;
using System;
using GlitchyEngine;

namespace GlitchyEditor.Ultralight;

class UltralightMainWindow : UltralightWindow
{
	public this() : base("Glitchy Engine", "file:///dist/index.html")
	{

	}
	
	private bool _hoveringNonClientArea;

	void HandleHoverNonClientArea(JSContextRef context, JSObjectRef thisObject, Span<JSValueRef> arguments, JSValueRef* exception = null)
	{
		Log.EngineLogger.Info("HandleHoverNonClientArea");

		if (arguments.Length != 1)
		{
			Log.EngineLogger.Error("EngineGlue.setHoverNonClientArea: called with wrong number of arguments.");
			return;
		}

		if (!JSValueIsBoolean(context, arguments[0]))
		{
			Log.EngineLogger.Error($"EngineGlue.setHoverNonClientArea: expected boolean, but received {JSValueGetType(context, arguments[0])} instead.");
			return;
		}

		_hoveringNonClientArea = JSValueToBoolean(context, arguments[0]);

		Log.ClientLogger.Info($"_hoveringNonClientArea: {_hoveringNonClientArea}");
	}

	private void RegisterBeefFunction(JSContextRef context, JSObjectRef object, StringView functionName, JSCallback callback)
	{
		JSObjectRef func = UltralightHelper.CreateJsFunctionFromDelegate(context, callback);
		
		JSStringRef name = JSStringCreateWithUTF8CString(functionName.ToScopeCStr!());

		JSObjectRef exception;
		JSObjectSetProperty(context, object, name, func, 0, &exception);

		JSStringRelease(name);
	}


	private void RegisterEngineGlueFunctions()
	{
		JSContextRef context = ulViewLockJSContext(_view);
		defer ulViewUnlockJSContext(_view);
		
		JSObjectRef globalObject = JSContextGetGlobalObject(context);
		
		JSValueRef exception = null;
		JSStringRef scriptGlueName = JSStringCreateWithUTF8CString("EngineGlue");
		JSValueRef scriptGlue = JSObjectGetProperty(context, globalObject, scriptGlueName, &exception);
		JSStringRelease(scriptGlueName);

		if (JSValueGetType(context, scriptGlue) == .kJSTypeUndefined)
		{
			Log.EngineLogger.Error("Failed to get EngineGlue object from JS context.");
			return;
		}

		StdAllocator stdAlloc = StdAllocator();

		RegisterBeefFunction(context, scriptGlue, "setHoverNonClientArea", new:stdAlloc => HandleHoverNonClientArea);
	}

	protected override void OnDOMReady(C_View* caller, uint64 frame_id, bool is_main_frame, C_String* url)
	{
		RegisterEngineGlueFunctions();

	}
}
