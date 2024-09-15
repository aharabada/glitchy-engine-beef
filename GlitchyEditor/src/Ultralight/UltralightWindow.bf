using System;
using GlitchyEngine;
using GlitchyEngine.Math;
using GlitchyEngine.Events;
using GlitchyEngine.Content;
using GlitchyEngine.Renderer;
using Ultralight;
using Ultralight.CAPI;

namespace GlitchyEditor.Ultralight;

abstract class UltralightWindow
{
	protected Window _window ~ delete _;

	protected ULView _view;

	private int2 _cursorPosition;
	
	private Texture2D _texture ~ _.ReleaseRef();

	protected this(StringView title = "GlitchyEngine ♥ Ultralight", StringView startUrl = "file:///app.html")
	{
		WindowDescription windowDesc = .Default;
		windowDesc.Title = title;

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

	private void InitView()
	{
		ULViewConfig viewConfig = ulCreateViewConfig();
		ulViewConfigSetIsAccelerated(viewConfig, false);
	  
		_view = ulCreateView(UltralightLayer.renderer, _window.SwapChain.Width, _window.SwapChain.Height, viewConfig, null);

		ulDestroyViewConfig(viewConfig);
	}

	private void InitCallbacks()
	{
		void* userData = Internal.UnsafeCastToPtr(this);

		ulViewSetDOMReadyCallback(_view, => OnDOMReady, userData);
		ulViewSetFailLoadingCallback(_view, => OnFailedLoading, userData);
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

		// TODO: before first resize the stride is larger than expected
		uint32 width = ulBitmapGetWidth(bitmap);
		uint32 height = ulBitmapGetHeight(bitmap);
		uint32 stride = ulBitmapGetRowBytes(bitmap);

		_texture.SetData<uint32>((.)pixels, 0, 0, width, height, 0, 0);

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

#endregion Events

#region Ultralight Callbacks

	private static void OnDOMReady(void* user_data, ULView caller, uint64 frame_id, bool is_main_frame, ULString url)
	{
		UltralightWindow window = (UltralightWindow)Internal.UnsafeCastToObject(user_data);
		window.OnDOMReady(caller, frame_id, is_main_frame, url);
	}

	protected virtual void OnDOMReady(ULView caller, uint64 frame_id, bool is_main_frame, ULString url) { }
	
	private static void OnFailedLoading(void* user_data, C_View* caller, uint64 frame_id, bool is_main_frame, C_String* url, C_String* description, C_String* error_domain, int32 error_code)
	{
		UltralightWindow window = (UltralightWindow)Internal.UnsafeCastToObject(user_data);
		window.OnFailedLoading(caller, frame_id, is_main_frame, url, description, error_domain, error_code);
	}
	
	protected virtual void OnFailedLoading(C_View* caller, uint64 frame_id, bool is_main_frame, C_String* url, C_String* description, C_String* error_domain, int32 error_code)
	{
		Log.EngineLogger.Error("Error while loading view.");
	}

#endregion Ultralight Callbacks
}
