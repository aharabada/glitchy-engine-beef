using System;
using GlitchyEngine;
using GlitchyEngine.Math;
using GlitchyEngine.Events;
using GlitchyEngine.Content;
using GlitchyEngine.Renderer;
using Ultralight;
using Ultralight.CAPI;
using DirectX.Windows;
using GlitchyEngine.UI;

namespace GlitchyEditor.Ultralight;

abstract class UltralightWindow
{
	protected internal Window _window ~ delete _;

	protected internal ULView _view;

	private int2 _cursorPosition;
	
	private Texture2D _texture ~ _.ReleaseRef();

	protected this(StringView title = "GlitchyEngine ♥ Ultralight", StringView startUrl = "file:///app.html")
	{
		WindowDescription windowDesc = .Default;
		windowDesc.Title = title;
		windowDesc.WindowStyle = .CustomTitle;

		_window = new Window(windowDesc);
		_window.EventCallback = new => EventHandler;

		Init(startUrl);
	}

#region Init

	private void Init(StringView startUrl)
	{
		InitView();

		InitCallbacks();

		LoadUrl(startUrl);

		CreateTexture();
	}

	protected virtual void InitView()
	{
		ULViewConfig viewConfig = ulCreateViewConfig();
		ulViewConfigSetIsAccelerated(viewConfig, false);
		ulViewConfigSetIsTransparent(viewConfig, true);

		_view = ulCreateView(UltralightLayer.renderer, _window.SwapChain.Width, _window.SwapChain.Height, viewConfig, null);

		ulDestroyViewConfig(viewConfig);
	}

	private void InitCallbacks()
	{
		void* userData = Internal.UnsafeCastToPtr(this);
		
		ulViewSetFailLoadingCallback(_view, => OnFailedLoading, userData);
		ulViewSetWindowObjectReadyCallback(_view, => OnWindowObjectReady, userData);
		ulViewSetDOMReadyCallback(_view, => OnDOMReady, userData);

		ulViewSetAddConsoleMessageCallback(_view, => OnAddConsoleMessage, userData);

		ulViewSetChangeCursorCallback(_view, => OnChangeCursor, userData);
	}

#endregion Init
	
	protected void LoadUrl(StringView targetUrl)
	{
		ULString url = ulCreateString(targetUrl.ToScopeCStr!());
		ulViewLoadURL(_view, url);
		ulDestroyString(url);
	}

	private void CopybitmapToTexture(ULBitmap bitmap)
	{
		void* pixels = ulBitmapLockPixels(bitmap);

		uint32 height = ulBitmapGetHeight(bitmap);
		uint32 stride = ulBitmapGetRowBytes(bitmap);

		_texture.SetData(TextureSliceData(pixels, stride, stride * height));

		ulBitmapUnlockPixels(bitmap);
	}

	private void CopyToImmediateTexture()
	{
		ULBitmapSurface surface = ulViewGetSurface(_view);

		if (surface != null && !ulIntRectIsEmpty(ulSurfaceGetDirtyBounds(surface)))
		{
			CopybitmapToTexture(ulBitmapSurfaceGetBitmap(surface));
			ulSurfaceClearDirtyBounds(surface);
		}
	}

	private void CopyToBackBuffer()
	{
		if (_window == null)
			return;

		RenderCommand.Clear(_window.SwapChain.BackBuffer, .Color, .(0.7f, 0.2f, 0.2f), 1.0f, 0);

		Blit.Blit(_texture, _window.SwapChain.BackBuffer, viewport: _window.SwapChain.BackbufferViewport);
	}

	public virtual void Update() { }

	public void Render()
	{
		CopyToImmediateTexture();
		CopyToBackBuffer();
	}

	private void CreateTexture()
	{
		if (_texture?.Width == _window.SwapChain.Width && _texture?.Height == _window.SwapChain.Height)
			return;

		Texture2DDesc desc = .(_window.SwapChain.Width, _window.SwapChain.Height, .B8G8R8A8_UNorm, usage: .Default, cpuAccess: .Write);

		Texture2D newTexture = new Texture2D(desc);
		newTexture.SamplerState = SamplerStateManager.PointClamp;

		_texture?.ReleaseRef();
		_texture = newTexture;
	}

	protected delegate JSValueRef JsFunctionCall(JSContextRef context, Span<JSValueRef> arguments, JSValueRef* exception);

	protected JsFunctionCall GetJsCallbackDelegate(JSContextRef context, JSObjectRef object, StringView functionName)
	{
		JSStringRef functionNameString = JSStringCreateWithUTF8CString(functionName.ToScopeCStr!());
		defer JSStringRelease(functionNameString);
		
		JSValueRef func = JSObjectGetProperty(context, object, functionNameString, null);

		if (!JSValueIsObject(context, func))
		{
			return null;
		}

		JSObjectRef functionObject = JSValueToObject(context, func, null);

		if (functionObject == null || !JSObjectIsFunction(context, functionObject))
		{
			return null;
		}
		
		return new (c, args, ex) => {
			return JSObjectCallAsFunction(c, functionObject, object, (uint32)args.Length, args.Ptr, ex);
		};
	}

	protected void BindMethodToJsFunction(JSContextRef context, JSObjectRef object, StringView functionName, JSCallback callback)
	{
		JSObjectRef func = UltralightHelper.CreateJsFunctionFromDelegate(context, callback);
		
		JSStringRef name = JSStringCreateWithUTF8CString(functionName.ToScopeCStr!());

		JSObjectRef exception;
		JSObjectSetProperty(context, object, name, func, 0, &exception);

		JSStringRelease(name);
	}
	
	//[BeefMethodBinder]
	protected virtual void BindBeefMethodsToJsFunctions(JSContextRef context, JSValueRef scriptGlue, StdAllocator stdAlloc)
	{
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
		BindBeefMethodsToJsFunctions(context, scriptGlue, stdAlloc);

		//uiCallUpdateEntities = GetJsCallbackDelegate(context, scriptGlue, "callFromEngine_updateEntities");
	}

#region Events

	private void EventHandler(Event e)
	{
		EventDispatcher dispatcher = EventDispatcher(e);

		dispatcher.Dispatch<MouseMovedEvent>(scope => MouseMoved);
		dispatcher.Dispatch<MouseButtonPressedEvent>(scope (e) => MousePressed(e, true));
		dispatcher.Dispatch<MouseButtonReleasedEvent>(scope (e) => MousePressed(e, false));
		dispatcher.Dispatch<KeyPressedEvent>(scope (e) => KeyEvent(e, true, e.RepeatCount));
		dispatcher.Dispatch<KeyReleasedEvent>(scope (e) => KeyEvent(e, false, 0));
		dispatcher.Dispatch<KeyTypedEvent>(scope (e) => CharTypedEvent(e));
		dispatcher.Dispatch<WindowCloseEvent>(scope (e) => {
			delete _window;
			_window = null;
			return true;
		});

		dispatcher.Dispatch<WindowResizeEvent>(scope => ResizeWindow);
	}

	bool ResizeWindow(WindowResizeEvent windowResizeEvent)
	{
		CreateTexture();
		ulViewResize(_view, (uint32)windowResizeEvent.Width, (uint32)windowResizeEvent.Height);

		return true;
	}

	private bool CharTypedEvent(KeyTypedEvent e)
	{
		String s = scope String();
		s.Append(e.Char);

		ULString str = ulCreateString(s.CStr());

		ULKeyEvent event = ulCreateKeyEvent(.kKeyEventType_Char,
			0, 0, 0, str, str, false, false, false);

		ulDestroyString(str);

		ulViewFireKeyEvent(_view, event);
		ulDestroyKeyEvent(event);

		return true;
	}

	private bool KeyEvent(KeyEvent e, bool pressed, int repeatCount)
	{
		bool isRepeat = repeatCount > 1;

		ULKeyCode keyCode = (ULKeyCode)e.KeyCode;

		ULString str = ulCreateString(keyCode.GetKeyIdentifier());

		ULKeyboardModifier modifier = 0;

		if (Input.IsKeyPressed(.Control))
			modifier |= .kMod_CtrlKey;
		
		if (Input.IsKeyPressed(.Alt))
			modifier |= .kMod_AltKey;

		if (Input.IsKeyPressed(.Shift))
			modifier |= .kMod_ShiftKey;
		
		if (Input.IsKeyPressed(.Home))
			modifier |= .kMod_MetaKey;

		ULKeyEvent event = ulCreateKeyEvent(pressed ? .kKeyEventType_RawKeyDown : .kKeyEventType_KeyUp,
			(uint32)modifier, (int32)keyCode, 0, str, str, false, isRepeat, false);

		ulDestroyString(str);

		for (int i < repeatCount)
		{
			ulViewFireKeyEvent(_view, event);
		}
		
		ulDestroyKeyEvent(event);

		return true;
	}

	private bool MouseMoved(MouseMovedEvent e)
	{
		ULMouseEvent evt = ulCreateMouseEvent(.kMouseEventType_MouseMoved, e.PositionX, e.PositionY,
			Input.IsMouseButtonPressed(.LeftButton) ? .kMouseButton_Left : .kMouseButton_None);
		ulViewFireMouseEvent(_view, evt);
		ulDestroyMouseEvent(evt);

		_cursorPosition = .(e.PositionX, e.PositionY);

		EditorLayer.CursorPos = _cursorPosition;

		return true;
	}

	private bool MousePressed(MouseButtonEvent e, bool press)
	{
		Log.ClientLogger.Warning($"{e.MouseButton} {press} {_cursorPosition.X} {_cursorPosition.Y}");

		ULMouseButton button = .kMouseButton_None;

		switch (e.MouseButton)
		{
		case .LeftButton: button = .kMouseButton_Left;
		case .RightButton: button = .kMouseButton_Right;
		case .MiddleButton: button = .kMouseButton_Middle;
		default: button = .kMouseButton_None;
		}

		ULMouseEvent evt = ulCreateMouseEvent(press ? .kMouseEventType_MouseDown : .kMouseEventType_MouseUp, _cursorPosition.X, _cursorPosition.Y, button);
		ulViewFireMouseEvent(_view, evt);
		ulDestroyMouseEvent(evt);

		return true;
	}

#endregion Events

#region Ultralight Callbacks
	
	private static void OnWindowObjectReady(void* user_data, ULView caller, uint64 frame_id, bool is_main_frame, ULString url)
	{
		UltralightWindow window = (UltralightWindow)Internal.UnsafeCastToObject(user_data);
		window.OnWindowObjectReady(caller, frame_id, is_main_frame, url);
	}

	protected virtual void OnWindowObjectReady(ULView caller, uint64 frame_id, bool is_main_frame, ULString url) { }

	private static void OnDOMReady(void* user_data, ULView caller, uint64 frame_id, bool is_main_frame, ULString url)
	{
		UltralightWindow window = (UltralightWindow)Internal.UnsafeCastToObject(user_data);
		window.OnDOMReady(caller, frame_id, is_main_frame, url);
	}

	protected virtual void OnDOMReady(ULView caller, uint64 frame_id, bool is_main_frame, ULString url)
	{
		RegisterEngineGlueFunctions();
	}

	private static void OnFailedLoading(void* user_data, C_View* caller, uint64 frame_id, bool is_main_frame, C_String* url, C_String* description, C_String* error_domain, int32 error_code)
	{
		UltralightWindow window = (UltralightWindow)Internal.UnsafeCastToObject(user_data);
		window.OnFailedLoading(caller, frame_id, is_main_frame, url, description, error_domain, error_code);
	}
	
	protected virtual void OnFailedLoading(C_View* caller, uint64 frame_id, bool is_main_frame, C_String* url, C_String* description, C_String* error_domain, int32 error_code)
	{
		Log.EngineLogger.Error("Error while loading view.");
	}

	private static void OnAddConsoleMessage(void* user_data, C_View* caller, ULMessageSource source, ULMessageLevel level, C_String* message, uint32 line_number, uint32 column_number, C_String* source_id)
	{
		UltralightWindow window = (UltralightWindow)Internal.UnsafeCastToObject(user_data);
		window.OnAddConsoleMessage(caller, source, level, message, line_number, column_number, source_id);
	}


	private static void OnChangeCursor(void* userData, C_View* caller, ULCursor ulCursor)
	{
		UltralightWindow window = (UltralightWindow)Internal.UnsafeCastToObject(userData);

		CursorImage cursor;

		switch (ulCursor)
		{
		case .kCursor_Pointer:
			cursor = .Pointer;

		case .kCursor_Cross:
			cursor = .Crosshair;

		case .kCursor_Hand:
			cursor = .Hand;

		case .kCursor_IBeam:
			cursor = .IBeam;

		case .kCursor_Wait:
			cursor = .Wait;

		case .kCursor_Help:
			cursor = .Help;

		case .kCursor_EastResize, .kCursor_WestResize, .kCursor_EastWestResize:
			cursor = .ResizeEastWest;

		case .kCursor_NorthResize, .kCursor_SouthResize, .kCursor_NorthSouthResize:
			cursor = .ResizeNorthSouth;

		case .kCursor_NorthEastResize, .kCursor_SouthWestResize, .kCursor_NorthEastSouthWestResize:
			cursor = .ResizeNorthEastSouthWest;

		case .kCursor_NorthWestResize, .kCursor_SouthEastResize, .kCursor_NorthWestSouthEastResize:
			cursor = .ResizeNorthWestSouthEast;

		case .kCursor_ColumnResize:
			cursor = .ResizeColumn;

		case .kCursor_RowResize:
			cursor = .ResizeRow;

		case .kCursor_MiddlePanning:
			cursor = .PanMiddle;
		case .kCursor_EastPanning:
			cursor = .PanEast;
		case .kCursor_WestPanning:
			cursor = .PanWest;
		case .kCursor_NorthPanning:
			cursor = .PanNorth;
		case .kCursor_SouthPanning:
			cursor = .PanSouth;
		case .kCursor_NorthEastPanning:
			cursor = .PanNorthEast;
		case .kCursor_NorthWestPanning:
			cursor = .PanNorthWest;
		case .kCursor_SouthEastPanning:
			cursor = .PanSouthEast;
		case .kCursor_SouthWestPanning:
			cursor = .PanSouthWest;

		case .kCursor_Move:
			cursor = .Move;

		case .kCursor_VerticalText:
			cursor = .VerticalText;

		case .kCursor_Cell:
			cursor = .Cell;

		case .kCursor_ContextMenu:
			cursor = .ContextMenu;

		case .kCursor_Alias:
			cursor = .Alias;

		case .kCursor_Progress:
			cursor = .Progress;

		case .kCursor_NoDrop, .kCursor_NotAllowed:
			cursor = .NotAllowed;

		case .kCursor_Copy:
			cursor = .Copy;

		case .kCursor_None:
			cursor = .None;

		case .kCursor_ZoomIn:
			cursor = .ZoomIn;
		case .kCursor_ZoomOut:
			cursor = .ZoomOut;

		case .kCursor_Grab:
			cursor = .Grab;
		case .kCursor_Grabbing:
			cursor = .Grabbing;

		case .kCursor_Custom:
			cursor = .Custom;
		}

		window._window.SetCursor(cursor);
	}
	
	protected virtual void OnAddConsoleMessage(C_View* caller, ULMessageSource source, ULMessageLevel level, C_String* message, uint32 line_number, uint32 column_number, C_String* source_id)
	{
		GlitchLog.LogLevel logLevel = .Info;

		switch (level)
		{
		case .kMessageLevel_Debug:
			logLevel = .Debug;
		case .kMessageLevel_Info:
			logLevel = .Info;
		case .kMessageLevel_Warning:
			logLevel = .Warning;
		case .kMessageLevel_Error:
			logLevel = .Error;
		default:
			logLevel = .Info;
		}

		StringView messageView = .(ulStringGetData(message), ulStringGetLength(message));
		StringView sourceIdView = .(ulStringGetData(source_id), ulStringGetLength(source_id));
		String prettyMessage = scope $"Ultralight ({source}) from \"{sourceIdView}\" in Line: {line_number}, Column: {column_number}. Message: {messageView}";

		Log.ClientLogger.Log(logLevel, prettyMessage);
	}

#endregion Ultralight Callbacks
}
