using Ultralight.CAPI;
using System;
using GlitchyEngine;
using static GlitchyEngine.UI.Window;

namespace GlitchyEditor.Ultralight;

class UltralightMainWindow : UltralightWindow
{
	public this() : base("Glitchy Engine", "file:///index.html")
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

		_window.[Friend]_hoveredOverTitleBar = _hoveringNonClientArea;

		EditorLayer.HoverCap = _window.[Friend]_hoveredOverTitleBar;

		Log.ClientLogger.Info($"_hoveringNonClientArea: {_hoveringNonClientArea}");
	}

	void HandleHoverTitlebarButton(TitleBarButton button, JSContextRef context, JSObjectRef thisObject, Span<JSValueRef> arguments, JSValueRef* exception = null)
	{
		if (arguments.Length != 1)
		{
			Log.EngineLogger.Error("EngineGlue.HandleHoverMaximizeWindow: called with wrong number of arguments.");
			return;
		}

		if (!JSValueIsBoolean(context, arguments[0]))
		{
			Log.EngineLogger.Error($"EngineGlue.HandleHoverMaximizeWindow: expected boolean, but received {JSValueGetType(context, arguments[0])} instead.");
			return;
		}

		Enum.SetFlagConditionally(ref _window.[Friend]_hoveredTitleBarButton, button, JSValueToBoolean(context, arguments[0]));
		
		EditorLayer.HoveredTitleBarButton = _window.[Friend]_hoveredTitleBarButton;
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
		
		RegisterBeefFunction(context, scriptGlue, "handleHoverNonClientArea", new:stdAlloc => HandleHoverNonClientArea);
		RegisterBeefFunction(context, scriptGlue, "handleHoverMaximizeWindow", new:stdAlloc (c, t, a, e) => HandleHoverTitlebarButton(.Maximize, c, t, a, e));
		RegisterBeefFunction(context, scriptGlue, "handleHoverMinimizeWindow", new:stdAlloc (c, t, a, e) => HandleHoverTitlebarButton(.Minimize, c, t, a, e));
		RegisterBeefFunction(context, scriptGlue, "handleHoverCloseWindow", new:stdAlloc (c, t, a, e) => HandleHoverTitlebarButton(.Close, c, t, a, e));
		RegisterBeefFunction(context, scriptGlue, "handleClickMaximizeWindow", new:stdAlloc (c, t, a, e) => { _window.ToggleMaximize(); });
		RegisterBeefFunction(context, scriptGlue, "handleClickMinimizeWindow", new:stdAlloc (c, t, a, e) => { _window.Minimize(); });
		RegisterBeefFunction(context, scriptGlue, "handleClickCloseWindow", new:stdAlloc (c, t, a, e) => { _window.Close(); });
	}

	protected override void OnDOMReady(C_View* caller, uint64 frame_id, bool is_main_frame, C_String* url)
	{
		RegisterEngineGlueFunctions();

	}
}
