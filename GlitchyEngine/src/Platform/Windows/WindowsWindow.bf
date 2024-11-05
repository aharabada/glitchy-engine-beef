#if BF_PLATFORM_WINDOWS

using System;
using DirectX.Common;
using DirectX.Windows;
using DirectX.Windows.Winuser;
using DirectX.Windows.Kernel32;
using DirectX.Windows.WindowMessages;
using GlitchyEngine.Events;
using System.Diagnostics;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using DirectX.Windows.Winuser.RawInput;
using System.Collections;
using static System.Windows;

using internal GlitchyEngine;

namespace GlitchyEngine.UI
{
	/// The windows specific Window implementation
	public extension Window
	{
		const String WindowClassName = "GlitchyEngineWindow";
		static readonly char16[?] WindowClassNameW = WindowClassName.ToConstNativeW();

		private static WindowClassExW WindowClass;

		private static Windows.HInstance _instanceHandle;
		internal Windows.HWnd _windowHandle;

		private WindowRectangle _clientRect;

		private MinMaxInfo _minMaxInfo;

		private String _title ~ delete _;

		private bool _isVSync = true;

		private bool _isActive;

		private HCURSOR _cursor;

		private WindowStyle _windowStyle;

		public enum TitleBarButton
		{
			None,
			Minimize = 1,
			Maximize = 2,
			Close = 4
		}

		private TitleBarButton _hoveredTitleBarButton;

		private bool _hoveredOverTitleBar;

		public override int32 MinWidth
		{
			get => _minMaxInfo.MinimumTrackingSize.x;
			set => _minMaxInfo.MinimumTrackingSize.x = value;
		}
		public override int32 MinHeight
		{
			get => _minMaxInfo.MinimumTrackingSize.y;
			set => _minMaxInfo.MinimumTrackingSize.y = value;
		}

		public override int32 MaxWidth
		{
			get => _minMaxInfo.MaximumTrackingSize.x;
			set => _minMaxInfo.MaximumTrackingSize.x = value;
		}

		public override int32 MaxHeight
		{
			get => _minMaxInfo.MaximumTrackingSize.y;
			set => _minMaxInfo.MaximumTrackingSize.y = value;
		}

		//
		// Size
		//
		public override int2 Size
		{
			get => *(int2*)&_clientRect.Width;

			set
			{
				*(int2*)&_clientRect.Width = value;
				ApplyRectangle();
			}
		}

		public override int32 Width
		{
			get => _clientRect.Width;

			set
			{
				_clientRect.Width = value;
				ApplyRectangle();
			}
		}

		public override int32 Height
		{
			get => _clientRect.Height;

			set
			{
				_clientRect.Height = value;
				ApplyRectangle();
			}
		}
		
		//
		// Position
		//
		public override int2 Position
		{
			get => *(int2*)&_clientRect;

			set
			{
				*(int2*)&_clientRect = value;
				ApplyRectangle();
			}
		}

		public override int32 PositionX
		{
			get => _clientRect.X;

			set
			{
				_clientRect.X = value;
				ApplyRectangle();
			}
		}

		public override int32 PositionY
		{
			get => _clientRect.Y;

			set
			{
				_clientRect.Y = value;
				ApplyRectangle();
			}
		}

		public override StringView Title
		{
			get
			{
				if (_title == null)
					LoadTitle();

				return _title;
			}

			set => SetWindowTextW(_windowHandle, value.ToScopedNativeWChar!());
		}

		public override bool IsVSync
		{
			get => _isVSync;
			set => _isVSync = value;
		}

		public override bool IsActive => _isActive;

		public override void* NativeWindow => (void*)(int)_windowHandle;

		public override this(WindowDescription desc)
		{
			Debug.Profiler.ProfileFunction!();

			_minMaxInfo.MaximumTrackingSize.x = int32.MaxValue;
			_minMaxInfo.MaximumTrackingSize.y = int32.MaxValue;

			Application.Instance.Windows.Add(this);

			Init(desc);
		}

		[LinkName(.C)]
		static extern Windows.IntBool DestroyWindow(Windows.HWnd hWnd);

		[LinkName("UnregisterClassW")]
		static extern Windows.IntBool UnregisterClass(char16* className, Windows.HInstance hInstance);

		public ~this()
		{
			Debug.Profiler.ProfileFunction!();

			if(!DestroyWindow(_windowHandle))
			{
				HResult res = (.)GetLastError();
				Log.EngineLogger.Error($"Failed to destroy window: Message ({(int)res}): {res}");
			}

			Application.Instance.Windows.Remove(this);
		}

		static ~this()
		{
#unwarn
			UnregisterClass(WindowClass.ClassName, _instanceHandle);
		}

		[LinkName(.C)]
		static extern HWnd GetActiveWindow();

		private void CreateWindowClass(StringView iconPath)
		{
			_instanceHandle = (.)GetModuleHandleW(null);

			WindowClass = .();
			WindowClass.Style = .HorizontalRedrawOnChange | .VerticalRedrawOnChange;
			WindowClass.WindowProcedure = => MessageHandler;
			WindowClass.HInstance = (.)_instanceHandle;

			if (iconPath.Ptr != null)
			{
				Debug.Profiler.ProfileScope!("LoadIcon");

				WindowClass.Icon = LoadImageW(0, iconPath.ToScopedNativeWChar!(), .Icon, 0, 0, .LoadFromFile);
			}
			else
				WindowClass.Icon = 0;

			_cursor = WindowClass.Cursor = LoadCursorW(0, IDC_ARROW);
			WindowClass.BackgroundBrush = (HBRUSH)SystemColor.WindowFrame;

#unwarn
			WindowClass.ClassName = &WindowClassNameW;

			if (RegisterClassExW(ref WindowClass) == 0)
			{
				uint32 lastError = GetLastError();
				Log.EngineLogger.Error($"Failed to register window class. Message({(int)lastError}): {(HResult)lastError}");
				Runtime.FatalError("Failed to register window class");
			}
		}

		[LinkName(.C)]
		static extern Windows.IntBool SetLayeredWindowAttributes(HWND hwnd, uint32 crKey, uint8 bAlpha, DWORD dwFlags);

		[CRepr]
		enum DpiAwarenessContext {
		    Invalid = -1,
		    Unaware = 0,
		    SystemAware = 1,
		    PerMonitorAware = 2
		}

		Handle DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = (.)-4;

		[CLink]
		static extern Windows.IntBool SetProcessDpiAwarenessContext(HANDLE value);

		private void Init(WindowDescription desc)
		{
			Debug.Profiler.ProfileFunction!();

			Log.EngineLogger.Trace($"Creating window \"{desc.Title}\" ({desc.Width}, {desc.Height})...");

			if (WindowClass == default)
			{
				// Support high-dpi screens
				if (!SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2))
				{
					Log.EngineLogger.Error("Could not set DPI awareness.");
				}

				CreateWindowClass(desc.Icon);
			}

			{
				Debug.Profiler.ProfileScope!("CreateWindow");

				DirectX.Windows.WindowStyles style = .WS_VISIBLE;

				_windowStyle = desc.WindowStyle;

				switch (desc.WindowStyle)
				{
				case .Normal:
					style |= .WS_OVERLAPPEDWINDOW | .WS_VISIBLE;
				case .Borderless:
					style |= .WS_POPUP | .WS_THICKFRAME | .WS_CAPTION | .WS_SYSMENU | .WS_MAXIMIZEBOX | .WS_MINIMIZEBOX;
				case .CustomTitle:
					style |= .WS_THICKFRAME   // required for a standard resizeable window
						    | .WS_SYSMENU      // Explicitly ask for the titlebar to support snapping via Win + ← / Win + →
						    | .WS_MAXIMIZEBOX  // Add maximize button to support maximizing via mouse dragging to the top of the screen
						    | .WS_MINIMIZEBOX;  // Add minimize button to support minimizing by clicking on the taskbar icon
				}
				
				void* selfPointer = Internal.UnsafeCastToPtr(this);
				_windowHandle = CreateWindowExW(.WS_EX_APPWINDOW, WindowClass.ClassName, desc.Title.ToScopedNativeWChar!(),
					style,
					CW_USEDEFAULT, CW_USEDEFAULT, desc.Width, desc.Height, 0, 0, (.)_instanceHandle, selfPointer);
			}

			_swapChain = new SwapChain(this);
			_swapChain.Init();
			
			LoadWindowRectangle();

			Log.EngineLogger.Trace($"Created window \"{Title}\" ({Width}, {Height})");

			// Determine whether or not the window is currently active
			_isActive = GetActiveWindow() == _windowHandle;

			if (!desc.Icon.IsEmpty)
				SetIcon(desc.Icon);
		}

		private bool _isResizingOrMoving;
		private bool _isMinimized;

		[CLink]
		static extern IntBool IsWindowUnicode(HWND whnd);

		public override Result<void> SetIcon(StringView filePath)
		{
			HICON hIcon = LoadImageW(0, filePath.ToScopedNativeWChar!(), .Icon, 0, 0, .LoadFromFile);
			if (hIcon == 0)
				return .Err;

			// WM_SETICON 0x0080
			SendMessageW(_windowHandle, 0x0080, 1 /* ICON_BIG */, (int)hIcon);

			return .Ok;
		}

		internal int2 _rawMouseMovementAccumulator;

		[CLink]
		private static extern IntBool InvalidateRect(HWND hWnd, in DirectX.Math.Rectangle lpRect, IntBool bErase);

		[CRepr]
		private struct CreateStructW
		{
			public LPVOID    lpCreateParams;
			public HINSTANCE hInstance;
			public HMENU     hMenu;
			public HWND      hwndParent;
			public int       cy;
			public int       cx;
			public int       y;
			public int       x;
			public LONG      style;
			public LPCWSTR   lpszName;
			public LPCWSTR   lpszClass;
			public DWORD     dwExStyle;
		}

		private static LRESULT MessageHandler(HWND hwnd, uint32 uMsg, WPARAM wParam, LPARAM lParam)
		{
			void* windowPtr = (void*)GetWindowLongPtrW(hwnd, GWL_USERDATA);
			Window window = (Window)Internal.UnsafeCastToObject(windowPtr);
			
			if (window == null)
			{
				if (uMsg == WM_CREATE)
				{
					// The pointer to our beef window is passed via lpParam of CreateWindowExW
					CreateStructW* createStruct = (CreateStructW*)(void*)lParam;
					void* windowPointer = createStruct.lpCreateParams;
					window = (Window)Internal.UnsafeCastToObject(windowPointer);
					SetWindowLongPtrW(hwnd, GWL_USERDATA, (int)windowPointer);
				}
				else
				{
					return DefWindowProcW(hwnd, uMsg, wParam, lParam);
				}
			}

			if (Application.Instance.MainWindow == window)
				ImGui.ImGuiImplWin32.WndProcHandler(hwnd, uMsg, wParam, lParam);

			switch (uMsg)
			{
				////
				//// Sizing and Moving
				////

				// Window min/max size requested
			case WM_GETMINMAXINFO:
				{
					MinMaxInfo* info = (.)(void*)lParam;
					info.MinimumTrackingSize = window._minMaxInfo.MinimumTrackingSize;
					info.MaximumTrackingSize = window._minMaxInfo.MaximumTrackingSize;
				}
				// Window size changed
			case WM_SIZE:
				{
					window._isMinimized = wParam == (.)ResizingType.Minimized;


					SplitHighAndLowOrder!(lParam, out window._clientRect.Width, out window._clientRect.Height);

					if(window._swapChain != null && window._clientRect.Width != 0 && window._clientRect.Height != 0)
					{
						window._swapChain.Width = (.)window._clientRect.Width;
						window._swapChain.Height = (.)window._clientRect.Height;
	
						window._swapChain.ApplyChanges();
					}

					WindowResizeEvent event = scope WindowResizeEvent(window._clientRect.Width, window._clientRect.Height, window._isResizingOrMoving);
					window._eventCallback(event);
				}
				// Window position changed
			case WM_MOVE:
				{
					if (wParam == (.)ResizingType.Minimized)
					{
						window._isMinimized = true;
					}
					else if (window._isMinimized)
					{
						window._isMinimized = false;
					}
					else
					{
						SplitHighAndLowOrder!(lParam, out window._clientRect.X, out window._clientRect.Y);

						var event = scope WindowMoveEvent(window._clientRect.X, window._clientRect.Y, window._isResizingOrMoving);
						window._eventCallback(event);
					}
				}
				// Window resizing/moving started
			case WM_ENTERSIZEMOVE:
				window._isResizingOrMoving = true;
				// Window resizing/moving ended
			case WM_EXITSIZEMOVE:
				{
					window._isResizingOrMoving = false;

					var resEvent = scope WindowResizeEvent(window._clientRect.Width, window._clientRect.Height, false);
					window._eventCallback(resEvent);
					var moveEvent = scope WindowMoveEvent(window._clientRect.X, window._clientRect.Y, false);
					window._eventCallback(moveEvent);
				}
				 
			case 0x0006: //WM_ACTIVATE
				{
					if (window._windowStyle == .CustomTitle)
					{
						DirectX.Math.Rectangle title_bar_rect = win32_titlebar_rect(hwnd);
						InvalidateRect(hwnd, title_bar_rect, false);
					}

					SplitHighAndLowOrder!((int64)wParam, let lowWParam, let highWParam);

					bool isActivate = lowWParam > 0;

					//HWnd windowHandle = (.)lParam;

					if(window._isActive != isActivate)
					{
						window._isActive = isActivate;

						if(window._isActive)
							window._eventCallback(scope WindowActivateEvent());
						else
							window._eventCallback(scope WindowDeactivateEvent());

					}
				}
				////
				//// Keyboard input
				////

			case WM_KEYDOWN, WM_SYSKEYDOWN:
				{
					Key key = WindowMessageToKey(wParam, lParam);
					var event = scope KeyPressedEvent(key, (int32)lParam & 0xFFFF);
					window._eventCallback(event);
				}
			case WM_KEYUP, WM_SYSKEYUP:
				{
					Key key = WindowMessageToKey(wParam, lParam);
					var event = scope KeyReleasedEvent(key);
					window._eventCallback(event);
				}

				////
				//// Mouse input
				////

				// Left mouse button
			case 0x00A1 /* WM_NCLBUTTONDOWN */:
				// Custom title windows need to handle mouse events outside of client area.
				if (window._windowStyle == .CustomTitle)
				{
					var event = scope MouseButtonPressedEvent(.LeftButton);
					window._eventCallback(event);

					if (window._hoveredTitleBarButton != .None)
						return 0;
				}
			case WM_LBUTTONDOWN:
				{
					var event = scope MouseButtonPressedEvent(.LeftButton);
					window._eventCallback(event);
				}
			case 0x00A2 /* WM_NCLBUTTONUP */:
				// Custom title windows need to handle mouse events outside of client area.
				if (window._windowStyle == .CustomTitle)
				{
					var event = scope MouseButtonReleasedEvent(.LeftButton);
					window._eventCallback(event);
					
					if (window._hoveredTitleBarButton != .None)
						return 0;
				}
			case WM_LBUTTONUP:
				{
					var event = scope MouseButtonReleasedEvent(.LeftButton);
					window._eventCallback(event);
				}
				// Right mouse button
			case WM_RBUTTONDOWN:
				{
					var event = scope MouseButtonPressedEvent(.RightButton);
					window._eventCallback(event);
				}
			case WM_RBUTTONUP:
				{
					var event = scope MouseButtonReleasedEvent(.RightButton);
					window._eventCallback(event);
				}
				// Middle mouse button
			case WM_MBUTTONDOWN:
				{
					var event = scope MouseButtonPressedEvent(.MiddleButton);
					window._eventCallback(event);
				}
			case WM_MBUTTONUP:
				{
					var event = scope MouseButtonReleasedEvent(.MiddleButton);
					window._eventCallback(event);
				}
				// X button
			case WM_XBUTTONDOWN:
				{
					MouseButton button = .None;
					if (HighOrder!((int64)wParam) == 1)
						button = .XButton1;
					else
						button = .XButton2;

					var event = scope MouseButtonPressedEvent(button);
					window._eventCallback(event);
				}
			case WM_XBUTTONUP:
				{
					MouseButton button = .None;
					if (HighOrder!((int64)wParam) == 1)
						button = .XButton1;
					else
						button = .XButton2;

					var event = scope MouseButtonReleasedEvent(button);
					window._eventCallback(event);
				}
				// Vertical scrolling
			case WM_MOUSEWHEEL:
				{
					int32 rotation = (int16)HighOrder!((int64)wParam) / WHEEL_DELTA;

					var event = scope MouseScrolledEvent(0, rotation);
					window._eventCallback(event);
				}
				// Horizontal scrolling
			case WM_MOUSEHWHEEL:
				{
					int32 rotation = (int16)HighOrder!((int64)wParam) / WHEEL_DELTA;

					var event = scope MouseScrolledEvent(rotation, 0);
					window._eventCallback(event);
				}
			case 0x00A0 /*WM_NCMOUSEMOVE*/:
				// Custom title windows need to handle mouse events outside of client area.
				if (window._windowStyle == .CustomTitle)
					fallthrough;
			case WM_MOUSEMOVE:
				{
					// If the mouse gets into the client area then no title bar buttons are hovered
					// so need to reset the hover state
					if (window._windowStyle == .CustomTitle && window._hoveredTitleBarButton != .None)
					{
						DirectX.Math.Rectangle title_bar_rect = win32_titlebar_rect(hwnd);
						// You could do tighter invalidation here but probably doesn't matter
						InvalidateRect(hwnd, title_bar_rect, false);
						//window._hoveredTitleBarButton = .None;
					}

					SplitXAndY(lParam, let x, let y);

					DirectX.Windows.POINT p = .(x, y);

					if (uMsg == 0x00A0 /*WM_NCMOUSEMOVE*/)
						ScreenToClient(hwnd, &p);
					
					var event = scope MouseMovedEvent(p.x, p.y);
					window._eventCallback(event);
				}
			/*case WM_INPUT:
				{
					uint32 dataSize = ?;
					GetRawInputData((.)lParam, RID_INPUT, null, &dataSize, sizeof(RAWINPUTHEADER));

					if (dataSize > 0)
					{
						uint8[] rawData = scope .[dataSize];
						if (GetRawInputData((.)lParam, RID_INPUT, rawData.CArray(), &dataSize, sizeof(RAWINPUTHEADER)) == dataSize)
						{
							RAWINPUT* raw = (.)rawData.CArray();
							if (raw.Header.Type == RIM_TYPEMOUSE)
							{
								var event = scope MouseMovedEvent(window, raw.Data.Mouse.lLastX, raw.Data.Mouse.lLastY);
								//window._eventCallback(event);

								// We accumulate the raw movements an collect them once each frame in WindowsInput.Impl_NewFrame()
								window._rawMouseMovementAccumulator += int2(raw.Data.Mouse.lLastX, raw.Data.Mouse.lLastY);
							}
						}
					}
				}*/

				// Todo: DirectInput

				////
				//// Application
				////
			case WM_CHAR:
				{
					var event = scope KeyTypedEvent((char16)wParam);
					window._eventCallback(event);

					return 0;
				}

				// Window title changed
			case WM_SETTEXT:
				{
					// Deletes and nulls _title so that it will be reloaded on the next call of Title.get
					delete window._title;
					window._title = null;
				}
			case WM_SETCURSOR:
				if (GetLowOrder(lParam) == /*HTCLIENT*/ 1)
				{
				    Winuser.SetCursor(window._cursor);

				    return 1;
				}
				break;
			case WM_SYSCOMMAND:
				{
					/* Remove beeping sound when ALT + some key is pressed. */
					if (wParam == SC_KEYMENU)
						return 0;
				}
				// Window closing
			case WM_CLOSE:
				{
					var event = scope WindowCloseEvent();
					window._eventCallback(event);

					return 0;
				}
				/**
				 * Removes the Windowframe
				 */
			case WM_NCCALCSIZE:
				if (window._windowStyle != .CustomTitle)
					break;

				if (wParam == 0)
					break;

				uint32 dpi = GetDpiForWindow(hwnd);

				int32 frame_x = GetSystemMetricsForDpi(SM_CXFRAME, dpi);
				int32 frame_y = GetSystemMetricsForDpi(SM_CYFRAME, dpi);
				int32 padding = GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);

				NCCALCSIZE_PARAMS* sizeParams = (NCCALCSIZE_PARAMS*)(void*)lParam;
				Rect* requested_client_rect = &sizeParams.rgrc[0];

				requested_client_rect.right -= frame_x + padding;
				requested_client_rect.left += frame_x + padding;
				requested_client_rect.bottom -= frame_y + padding;

				if (win32_window_is_maximized(hwnd)) {
				  requested_client_rect.top += padding;
				}

				return 0;
			case WM_CREATE:
				if (window._windowStyle != .CustomTitle)
					break;

				GetWindowRect(hwnd, let size_rect);

				// Inform the application of the frame change to force redrawing with the new
				// client area that is extended into the title bar
				SetWindowPos(
				  hwnd, 0,
				  size_rect.Left, size_rect.Top,
				  size_rect.Right - size_rect.Left, size_rect.Bottom - size_rect.Top,
				  0x0020 | 0x0002 | 0x0001 /*SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE*/
				);
			case 0x0084: /* WM_NCHITTEST */
				if (window._windowStyle != .CustomTitle)
					break;
				
				// Let the default procedure handle resizing areas
				LRESULT hit = DefWindowProcW(hwnd, uMsg, wParam, lParam);
				switch (hit)
				{
				case 0 /* HTNOWHERE */,
					10 /* HTLEFT */,
					11 /* HTRIGHT */,
					12 /* HTTOP */,
					13 /* HTTOPLEFT */,
					14 /* HTTOPRIGHT */,
					15 /* HTBOTTOM */,
					16 /* HTBOTTOMLEFT */,
					17 /* HTBOTTOMRIGHT */:
					return hit;
				}
				
				// Check if hover button is on maximize to support SnapLayout on Windows 11
				if (window._hoveredTitleBarButton.HasFlag(.Maximize))
				{
					return 9 /* HTMAXBUTTON */;
				}

				// Looks like adjustment happening in NCCALCSIZE is messing with the detection
				// of the top hit area so manually fixing that.
				uint32 dpi = GetDpiForWindow(hwnd);
				int frame_y = GetSystemMetricsForDpi(SM_CYFRAME, dpi);
				int padding = GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
				POINT cursor_point = .();

				cursor_point.x = GetXParam(lParam);
				cursor_point.y = GetYParam(lParam);
				ScreenToClient(hwnd, &cursor_point);
				if (cursor_point.y > 0 && cursor_point.y < frame_y + padding)
				{
				  	return 12 /* HTTOP */;
				}

				// Since we are drawing our own caption, this needs to be a custom test
				if (window._hoveredTitleBarButton == .None && window._hoveredOverTitleBar)
				{
					return 2 /* HTCAPTION */;
				}

				return 1 /* HTCLIENT */;
			}

			return DefWindowProcW(hwnd, uMsg, wParam, lParam);
		}

		public static void SplitXAndY(int64 input, out int32 x, out int32 y)
		{
			x = GetXParam(input);
			y = GetYParam(input);
		}

		[Inline]
		public static int32 GetXParam(int64 input)
		{
			return ((int32)(int16)GetLowOrder(input));
		}

		[Inline]
		public static int32 GetYParam(int64 input)
		{
			return ((int32)(int16)GetHighOrder(input));
		}

		static bool win32_window_is_maximized(HWND handle)
		{
			WINDOWPLACEMENT placement = .();
			placement.length = sizeof(WINDOWPLACEMENT);
			if (GetWindowPlacement(handle, &placement))
			{
				return placement.showCmd == SW_SHOWMAXIMIZED;
			}
			return false;
		}

		[CRepr]
		struct WINDOWPLACEMENT
		{
		    public uint32 length;
		    public uint32 flags;
		    public uint32 showCmd;
		    public POINT ptMinPosition;
		    public POINT ptMaxPosition;
		    public Rect rcNormalPosition;
		}

		[CLink]
		private static extern IntBool GetWindowPlacement(HWND hWnd, WINDOWPLACEMENT* lpwndpl);

		[CRepr]
		private struct NCCALCSIZE_PARAMS
		{
		    public Rect[3] rgrc;
		    public WINDOWPOS* lppos;
		}
		
		[CRepr]
		struct WINDOWPOS
		{
		    public HWND hwnd;
		    public HWND hwndInsertAfter;
		    public int32 x;
		    public int32 y;
		    public int32 cx;
		    public int32 cy;
		    public uint32 flags;
		}

		[CLink]
		private static extern uint32 GetDpiForWindow(HWND hwnd);

		[CLink]
		private static extern int32 GetSystemMetricsForDpi(int32 nIndex, uint32 dpi);

		private const int32 SM_CXFRAME = 32;
		private const int32 SM_CYFRAME = 33;
		private const int32 SM_CXPADDEDBORDER = 92;

		/**
		 * Converts the wParam and lParam of a WM_KEYDOWN or WM_KEYUP message to the corresponding engine keycode.
		 */
		static Key WindowMessageToKey(WPARAM wParam, LPARAM lParam)
		{
			Key key = Key.FromWindowsKeyCode((.)wParam);
			
			var scancode = (lParam & 0x00ff0000) >> 16;
			bool isExtended = (lParam & 0x01000000) > 0;

			switch(key)
			{
			case .Shift:
				return Key.FromWindowsKeyCode((.)MapVirtualKeyW((.)scancode, MAPVK_VSC_TO_VK_EX));
			case .Control:
				return isExtended ? .RightControl : .LeftControl;
			case .Alt:
				return isExtended ? .RightAlt : .LeftAlt;
			default:
				return key;
			}
		}

		struct SIZE
		{
			public LONG cx;
			public LONG cy;
		};

		[CLink, Import("UxTheme.lib")]
		private static extern Handle OpenThemeData(HWND hwnd, LPCWSTR pszClassList);

		[CLink, Import("UxTheme.lib")]
		private static extern HResult CloseThemeData(Handle hTheme);

		enum ThemeSize
		{
		    Min,             // minimum size
		    True,            // size without stretching
		    Draw             // size that theme mgr will use to draw part
		};

		[CLink, Import("UxTheme.lib")]
		private static extern HResult GetThemePartSize(Handle hTheme, Handle hdc, int32 iPartId, int32 iStateId, Rect* prc, ThemeSize eSize, SIZE* psz);

		static int32 win32_dpi_scale(int32 value, uint32 dpi)
		{
			return (int32)((float)value * dpi / 96);
		}

		// Adopted from:
		// https://github.com/oberth/custom-chrome/blob/master/source/gui/window_helper.hpp#L52-L64
		static DirectX.Math.Rectangle win32_titlebar_rect(HWND handle)
		{
		    SIZE title_bar_size = .();
		    const int top_and_bottom_borders = 2;
		    Handle theme = OpenThemeData(handle, "WINDOW".ToScopedNativeWChar!());
		    uint32 dpi = GetDpiForWindow(handle);
		    GetThemePartSize(theme, 0, 1/*WP_CAPTION*/, 1/*CS_ACTIVE*/, null, .True, &title_bar_size);
		    CloseThemeData(theme);

		    int32 height = win32_dpi_scale(title_bar_size.cy, dpi) + top_and_bottom_borders;

		    GetClientRect(handle, var rect);
		    rect.Bottom = rect.Top + height;
		    return rect;
		}

		public override void Update()
		{
			Debug.Profiler.ProfileFunction!();

			Message message = .();
			while (PeekMessageW(&message, 0, 0, 0, .Remove))
			{
				TranslateMessage(&message);
				DispatchMessageW(&message);
			}
		}

		private void LoadWindowRectangle()
		{
			GetClientRect(_windowHandle, let rectangle);

			_clientRect.X = rectangle.Left;
			_clientRect.Y = rectangle.Top;
			_clientRect.Width = rectangle.Right - rectangle.Left;
			_clientRect.Height = rectangle.Bottom - rectangle.Top;
		}

		private void ApplyRectangle()
		{
			SetWindowPos(_windowHandle, 0, _clientRect.X, _clientRect.Y, _clientRect.Width, _clientRect.Height, 0);
		}

		[LinkName(.C)]
		private static extern IntBool SetWindowPos(HWND hWnd, HWND hWndInsertAfter, int32 X, int32 Y, int32 cx, int32 cy, uint32 uFlags);

		/**
		 * Gets the window title via WinApi and stores it in _title.
		 */
		private void LoadTitle()
		{
			int32 length = GetWindowTextLengthW(_windowHandle) + 1;

			char16[] chars = scope char16[length];

			Span<char16> titleSpan = .(chars, 0, length - 1);

			GetWindowTextW(_windowHandle, chars.CArray(), length);

			_title = new String(titleSpan);
		}

		[CLink]
		private static extern HCURSOR LoadCursorFromFileW(LPCWSTR lpFileName);
		
		[CLink]
		private static extern IntBool DestroyCursor(HCURSOR hCursor);

		private static HCURSOR ResizeColumnCursor = 0 ~ DestroyCursor(_);
		private static HCURSOR VerticalTextCursor = 0 ~ DestroyCursor(_);
		private static HCURSOR ColResizeCursor = 0 ~ DestroyCursor(_);
		private static HCURSOR RowResizeCursor = 0 ~ DestroyCursor(_);
		private static HCURSOR CellCursor = 0 ~ DestroyCursor(_);
		private static HCURSOR AliasCursor = 0 ~ DestroyCursor(_);
		private static HCURSOR CopyCursor = 0 ~ DestroyCursor(_);
		private static HCURSOR ZoomInCursor = 0 ~ DestroyCursor(_);
		private static HCURSOR ZoomOutCursor = 0 ~ DestroyCursor(_);
		private static HCURSOR GrabCursor = 0 ~ DestroyCursor(_);
		private static HCURSOR GrabbingCursor = 0 ~ DestroyCursor(_);

		public override Result<void> SetCursor(CursorImage cursorImage)
		{
			LPCTSTR cursor = null;
			Handle hCursor = 0;

			void UseCustomCursor(ref HCURSOR cursor, StringView path)
			{
				if (cursor == 0)
					cursor = LoadCursorFromFileW(path.ToScopedNativeWChar!());

				hCursor = cursor;
			}

			switch (cursorImage)
			{
			case .Pointer:
				cursor = Winuser.IDC_ARROW;

			case .Crosshair:
				cursor = Winuser.IDC_CROSS;

			case .Hand:
				cursor = Winuser.IDC_HAND;

			case .IBeam:
				cursor = Winuser.IDC_IBEAM;

			case .Wait:
				cursor = Winuser.IDC_WAIT;

			case .Help:
				cursor = Winuser.IDC_HELP;

			case .ResizeEastWest:
				cursor = Winuser.IDC_SIZEWE;

			case .ResizeNorthSouth:
				cursor = Winuser.IDC_SIZENS;

			case .ResizeNorthEastSouthWest:
				cursor = Winuser.IDC_SIZENESW;

			case .ResizeNorthWestSouthEast:
				cursor = Winuser.IDC_SIZENWSE;

			case .ResizeColumn:
				UseCustomCursor(ref ColResizeCursor, "Resources/Cursors/col_resize.cur");

			case .ResizeRow:
				UseCustomCursor(ref RowResizeCursor, "Resources/Cursors/row_resize.cur");

			case .PanMiddle:
				cursor = Winuser.MAKEINTRESOURCEW(32654);
			case .PanEast:
				cursor = Winuser.MAKEINTRESOURCEW(32658);
			case .PanWest:
				cursor = Winuser.MAKEINTRESOURCEW(32657);
			case .PanNorth:
				cursor = Winuser.MAKEINTRESOURCEW(32655);
			case .PanSouth:
				cursor = Winuser.MAKEINTRESOURCEW(32656);
			case .PanNorthEast:
				cursor = Winuser.MAKEINTRESOURCEW(32660);
			case .PanNorthWest:
				cursor = Winuser.MAKEINTRESOURCEW(32659);
			case .PanSouthEast:
				cursor = Winuser.MAKEINTRESOURCEW(32662);
			case .PanSouthWest:
				cursor = Winuser.MAKEINTRESOURCEW(32661);

			case .Move:
				cursor = Winuser.IDC_SIZEALL;

			case .VerticalText:
				UseCustomCursor(ref VerticalTextCursor, "Resources/Cursors/vertical_text.cur");

			case .Cell:
				UseCustomCursor(ref CellCursor, "Resources/Cursors/cell.cur");

			case .ContextMenu:
				// TODO
				cursor = Winuser.IDC_ARROW;

			case .Alias:
				UseCustomCursor(ref AliasCursor, "Resources/Cursors/aliasb.cur");

			case .Progress:
				cursor = Winuser.IDC_APPSTARTING;

			case .NotAllowed:
				cursor = Winuser.IDC_NO;

			case .Copy:
				UseCustomCursor(ref CopyCursor, "Resources/Cursors/copy.cur");

			case .ZoomIn:
				UseCustomCursor(ref ZoomInCursor, "Resources/Cursors/zoom_in.cur");
			case .ZoomOut:
				UseCustomCursor(ref ZoomOutCursor, "Resources/Cursors/zoom_out.cur");

			case .Grab:
				UseCustomCursor(ref GrabCursor, "Resources/Cursors/grab.cur");
			case .Grabbing:
				UseCustomCursor(ref GrabbingCursor, "Resources/Cursors/grabbing.cur");

			case .Custom:
				// TODO
				cursor = Winuser.IDC_ARROW;

			case .None:
				cursor = null;
			}

			if (hCursor == 0)
			{
				hCursor = Winuser.LoadCursorW((.)0, cursor);
			}

			if (_cursor != hCursor)
			{
				_cursor = hCursor;
				Winuser.SetCursor(hCursor);
			}

			return .Ok;
		}

		public override void ToggleMaximize()
		{
			PostMessageW(_windowHandle, WM_SYSCOMMAND, win32_window_is_maximized(_windowHandle) ? SC_RESTORE : SC_MAXIMIZE, 0);
		}

		public override void Minimize()
		{
			PostMessageW(_windowHandle, WM_SYSCOMMAND, SC_MINIMIZE, 0);
		}

		public override void Close()
		{
			// TODO!
			Application.Instance.Close();
		}
	}
}

#endif