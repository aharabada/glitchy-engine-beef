using System;
using DirectX.Common;
using DirectX.Windows;
using DirectX.Windows.Winuser;
using DirectX.Windows.Kernel32;
using DirectX.Windows.WindowMessages;
using GlitchyEngine.Events;
using System.Diagnostics;

namespace GlitchyEngine.Platform.Windows
{
	public class WindowsWindow : Window
	{
		private Windows.HInstance _instanceHandle;
		private Windows.HWnd _windowHandle;

		private WindowClassExW _windowClass;

		private WindowRectangle _clientRect;

		private MinMaxInfo _minMaxInfo;

		private String _title ~ delete _;

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
				if(_title == null)
					LoadTitle();

				return _title;
			}

			set => SetWindowTextW(_windowHandle, value.ToScopedNativeWChar!());
		}

		public override bool IsVSync
		{
			get;
			set;
		}

		public this(WindowDescription desc)
		{
			_minMaxInfo.MaximumTrackingSize.x = int32.MaxValue;
			_minMaxInfo.MaximumTrackingSize.y = int32.MaxValue;

			Init(desc);
		}

		private void Init(WindowDescription desc)
		{
			Log.EngineLogger.Trace("Creating window \"{}\" ({}, {})...", desc.Title, desc.Width, desc.Height);

			_instanceHandle = (.)GetModuleHandleW(null);

			_windowClass = .();
			_windowClass.Style = .HorizontalRedrawOnChange | .VerticalRedrawOnChange;
			_windowClass.WindowProcedure = => MessageHandler;
			_windowClass.HInstance = (.)_instanceHandle;

			if(desc.Icon.Ptr != null)
				_windowClass.Icon = LoadImageW(0, desc.Icon.ToScopedNativeWChar!(), .Icon, 0, 0, .LoadFromFile);
			else
				_windowClass.Icon = 0;
			
			_windowClass.Cursor = LoadCursorW(0, IDC_ARROW);
			_windowClass.BackgroundBrush = (HBRUSH)SystemColor.WindowFrame;
			_windowClass.ClassName = "GlitchyEngineWindow".ToScopedNativeWChar!();

			if(RegisterClassExW(ref _windowClass) == 0)
			{
				Log.EngineLogger.Error("Failed to register window class.", (HResult)GetLastError());
				Runtime.FatalError("Failed to register window class");
			}

			_windowHandle = CreateWindowExW(.None, _windowClass.ClassName, desc.Title.ToScopedNativeWChar!(), .WS_OVERLAPPEDWINDOW | .WS_VISIBLE,
				CW_USEDEFAULT, CW_USEDEFAULT, desc.Width, desc.Height, 0, 0, (.)_instanceHandle, null);

			void* myPtr = Internal.UnsafeCastToPtr(this);

			SetWindowLongPtrW(_windowHandle, GWL_USERDATA, (int)myPtr);

			LoadWindowRectangle();
			
			Log.EngineLogger.Trace("Created window \"{}\" ({}, {})", Title, Width, Height);
		}

		private bool _isResizingOrMoving;
		private bool _isMinimized;

		private static LRESULT MessageHandler(HWND hwnd, uint32 uMsg, WPARAM wParam, LPARAM lParam)
		{
			void* windowPtr = (void*)GetWindowLongPtrW(hwnd, GWL_USERDATA);
			WindowsWindow window = (WindowsWindow)Internal.UnsafeCastToObject(windowPtr);

			if(window == null)
			{
				return DefWindowProcW(hwnd, uMsg, wParam, lParam);
			}

			switch(uMsg)
			{
				////
				//// Sizing and Moving
				////

				// Window min/max size requested
			case WM_GETMINMAXINFO:
				{
					MinMaxInfo *info = (.)(void*)lParam;
					info.MinimumTrackingSize = window._minMaxInfo.MinimumTrackingSize;
					info.MaximumTrackingSize = window._minMaxInfo.MaximumTrackingSize;
				}
				// Window size changed
			case WM_SIZE:
				{
					if(wParam == (.)ResizingType.Minimized)
					{
					    window._isMinimized = true;
					}
					else if (window._isMinimized)
					{
					    window._isMinimized = false;
					}
					else
					{
						SplitHighAndLowOrder!(lParam, out window._clientRect.Width, out window._clientRect.Height);

						WindowResizeEvent event = scope WindowResizeEvent(window._clientRect.Width, window._clientRect.Height, window._isResizingOrMoving);
						window._eventCallback(event);
					}
				}
				// Window position changed
			case WM_MOVE:
				{
					if(wParam == (.)ResizingType.Minimized)
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

				////
				//// Keyboard input
				////

			case WM_KEYDOWN:
				{
					var event = scope KeyPressedEvent((int32)wParam, (int32)lParam & 0xFFFF);
					window._eventCallback(event);
				}
			case WM_KEYUP:
				{
					var event = scope KeyReleasedEvent((int32)wParam);
					window._eventCallback(event);
				}

				////
				//// Mouse input
				////

				// Left mouse button
			case WM_LBUTTONDOWN:
				{
					var event = scope MouseButtonPressedEvent(.LeftButton);
					window._eventCallback(event);
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
					if(HighOrder!((int64)wParam) == 1)
						button = .XButton1;
					else
						button = .XButton2;

					var event = scope MouseButtonPressedEvent(button);
					window._eventCallback(event);
				}
			case WM_XBUTTONUP:
				{
					MouseButton button = .None;
					if(HighOrder!((int64)wParam) == 1)
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
			case WM_MOUSEMOVE:
				{
					SplitHighAndLowOrder!(lParam, let x, let y);
					
					var event = scope MouseMovedEvent(x, y);
					window._eventCallback(event);
				}

				// Todo: DirectInput

				////
				//// Application
				////

				// Window title changed
			case WM_SETTEXT:
				{
					// Deletes and nulls _title so that it will be reloaded on the next call of Title.get
					delete window._title;
					window._title = null;
				}
			case WM_SYSCOMMAND:
				{
					/* Remove beeping sound when ALT + some key is pressed. */
					if ( wParam == SC_KEYMENU )
					{
					    return 0;
					}
				}
				// Window closing
			case WM_CLOSE:
				{
					PostQuitMessage(0);

					var event = scope WindowCloseEvent();
					window._eventCallback(event);
				}
			}

			return DefWindowProcW(hwnd, uMsg, wParam, lParam);
		}

		public override void Update()
		{
			Message message = .();
			while (PeekMessageW(&message, 0, 0, 0, .Remove))
			{
				TranslateMessage(&message);
				DispatchMessageW(&message);
			}
		}
		
		private void LoadWindowRectangle()
		{
			GetWindowRect(_windowHandle, let rectangle);

			_clientRect.X = rectangle.Left;
			_clientRect.Y = rectangle.Top;
			_clientRect.Width = rectangle.Right - rectangle.Left;
			_clientRect.Height = rectangle.Bottom - rectangle.Top;
		}

		private void ApplyRectangle()
		{
			SetWindowPos(_windowHandle, 0, _clientRect.X, _clientRect.Y, _clientRect.Width, _clientRect.Height, 0);
		}

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
	}
}
