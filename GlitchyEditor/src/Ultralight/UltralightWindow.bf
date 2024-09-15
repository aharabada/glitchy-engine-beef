using System;
using GlitchyEngine;
using GlitchyEngine.Math;
using GlitchyEngine.Events;
using GlitchyEngine.Content;
using GlitchyEngine.Renderer;
using Ultralight;
using Ultralight.CAPI;

namespace GlitchyEditor.Ultralight;

class UltralightWindow
{
	private Window _window ~ delete _;

	private ULView _view;

	private int2 _cursorPosition;
	
	private Texture2D _texture ~ _.ReleaseRef();

	public this()
	{
		WindowDescription windowDesc = .Default;
		windowDesc.Title = "GlitchyEngine ♥ Ultralight";

		_window = new Window(windowDesc);
		_window.EventCallback = new => EventHandler;

		CreateView();
	}
	
	private void CopybitmapToTexture(ULBitmap bitmap)
	{
		void* pixels = ulBitmapLockPixels(bitmap);

		// TODO: before first resize the stride is larger than expected
		uint32 width = ulBitmapGetWidth(bitmap);
		uint32 height = ulBitmapGetHeight(bitmap);
		uint32 stride = ulBitmapGetRowBytes(bitmap);

		_texture.SetData<uint32>((.)pixels, 0, 0, width, height, 0, 0);

		ulBitmapUnlockPixels(bitmap);
	}

	public void Render()
	{
		ULBitmapSurface surface = ulViewGetSurface(_view);

		if (surface != null && !ulIntRectIsEmpty(ulSurfaceGetDirtyBounds(surface)))
		{
			CopybitmapToTexture(ulBitmapSurfaceGetBitmap(surface));
			ulSurfaceClearDirtyBounds(surface);
		}

		if (_window == null)
			return;
		
		RenderCommand.Clear(_window.SwapChain.BackBuffer, .Color, .(0.7f, 0.2f, 0.2f), 1.0f, 0);
		
		RenderCommand.UnbindRenderTargets();
		RenderCommand.SetRenderTarget(_window.SwapChain.BackBuffer);
		RenderCommand.BindRenderTargets();
		RenderCommand.SetViewport(_window.SwapChain.BackbufferViewport);

		Effect copy = Content.GetAsset<Effect>(UltralightLayer._copyEffect);
		copy.SetTexture("Texture", _texture);
		copy.ApplyChanges();
		copy.Bind();

		FullscreenQuad.Draw();
	}

	private void CreateView()
	{
		ULViewConfig viewConfig = ulCreateViewConfig();
		ulViewConfigSetIsAccelerated(viewConfig, false);
	  
		_view = ulCreateView(UltralightLayer.renderer, _window.SwapChain.Width, _window.SwapChain.Height, viewConfig, null);

		ulViewSetDOMReadyCallback(_view, => OnDOMReady, Internal.UnsafeCastToPtr(this));

		ulDestroyViewConfig(viewConfig);

		ulViewSetFailLoadingCallback(_view, (user_data, caller, frame_id, is_main_frame, url, description, error_domain, error_code) => {
		   Log.ClientLogger.Error("Error");
		}, null);

		ULString url = ulCreateString("file:///app.html");
		ulViewLoadURL(_view, url);
		ulDestroyString(url);

		CreateTexture();
	}

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
		Log.EngineLogger.Warning($"{e.PositionX}");

		ULMouseEvent evt = ulCreateMouseEvent(.kMouseEventType_MouseMoved, e.PositionX, e.PositionY,
			Input.IsMouseButtonPressed(.LeftButton) ? .kMouseButton_Left : .kMouseButton_None);
		ulViewFireMouseEvent(_view, evt);
		ulDestroyMouseEvent(evt);

		_cursorPosition = .(e.PositionX, e.PositionY);

		return true;
	}

	private bool MousePressed(MouseButtonEvent e, bool press)
	{
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
	
	///
	/// This callback is bound to a JavaScript function on the page.
	///
	static JSValueRef GetMessage(JSContextRef ctx, JSObjectRef fn, JSObjectRef thisObject, uint32 argumentCount, JSValueRef* arguments, JSValueRef* exception) {
		///
		/// Create a JavaScript String from a C-string, initialize it with our
		/// welcome message.
		///
		JSStringRef str = JSStringCreateWithUTF8CString("Hello from Beef!");
		
		///
		/// Create a garbage-collected JSValue using the String we just created.
		///
		///  **Note**:
		///    Both JSValueRef and JSObjectRef types are garbage-collected types. (And actually,
		///    JSObjectRef is just a typedef of JSValueRef, they share definitions).
		///
		///    The garbage collector in JavaScriptCore periodically scans the entire stack to check if
		///    there are any active JSValueRefs, and marks those with no references for destruction.
		///
		///    If you happen to store a JSValueRef/JSObjectRef in heap memory or in memory unreachable
		///    by the stack-based garbage-collector, you should explicitly call JSValueProtect() and
		///    JSValueUnprotect() on the reference to ensure it is kept alive.
		///
		JSValueRef value = JSValueMakeString(ctx, str);
		
		///
		/// Release the string we created earlier (we only Release what we Create).
		///
		JSStringRelease(str);
		
		return value;
	}

	private static void OnDOMReady(void* user_data, ULView caller, uint64 frame_id, bool is_main_frame, ULString url)
	{
		UltralightWindow window = (UltralightWindow)Internal.UnsafeCastToObject(user_data);
		window.OnDOMReady(caller, frame_id, is_main_frame, url);
	}

	protected virtual void OnDOMReady(ULView caller, uint64 frame_id, bool is_main_frame, ULString url)
	{
		///
		/// Acquire the page's JavaScript execution context.
		///
		/// This locks the JavaScript context so we can modify it safely on this thread, we need to
		/// unlock it when we're done via ulViewUnlockJSContext().
		///
		JSContextRef ctx = ulViewLockJSContext(_view);

		///
		/// Create a JavaScript String containing the name of our callback.
		///
		JSStringRef name = JSStringCreateWithUTF8CString("GetMessage");

		///
		/// Create a garbage-collected JavaScript function that is bound to our native C callback 
		/// 'GetMessage()'.
		///
		JSObjectRef func = JSObjectMakeFunctionWithCallback(ctx, name, => GetMessage);

		///
		/// Store our function in the page's global JavaScript object so that it is accessible from the
		/// page as 'GetMessage()'.
		///
		/// The global JavaScript object is also known as 'window' in JS.
		///
		JSObjectSetProperty(ctx, JSContextGetGlobalObject(ctx), name, func, 0, null);

		///
		/// Release the JavaScript String we created earlier.
		///
		JSStringRelease(name);

		///
		/// Unlock the JS context so other threads can modify JavaScript state.
		///
		ulViewUnlockJSContext(_view);
	}
}
