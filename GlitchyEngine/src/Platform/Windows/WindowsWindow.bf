#if GE_WINDOWS
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
using static System.Windows;

namespace GlitchyEngine
{
	/// The windows specific Window implementation
	public extension Window
	{
		const String WindowClassName = "GlitchyEngineWindow";

		private Windows.HInstance _instanceHandle;
		private Windows.HWnd _windowHandle;

		private WindowClassExW _windowClass;

		private WindowRectangle _clientRect;

		private MinMaxInfo _minMaxInfo;

		private String _title ~ delete _;

		private bool _isVSync = true;

		private GraphicsContext _graphicsContext ~ _?.ReleaseRef();

		public override GraphicsContext Context => _graphicsContext;

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
		public override Point Size
		{
			get => *(Point*)&_clientRect.Width;

			set
			{
				*(Point*)&_clientRect.Width = value;
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
		public override Point Position
		{
			get => *(Point*)&_clientRect;

			set
			{
				*(Point*)&_clientRect = value;
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

		public override void* NativeWindow => (void*)(int)_windowHandle;

		public override this(WindowDescription desc)
		{
			_minMaxInfo.MaximumTrackingSize.x = int32.MaxValue;
			_minMaxInfo.MaximumTrackingSize.y = int32.MaxValue;

			Init(desc);
		}

		[LinkName(.C)]
		static extern Windows.IntBool DestroyWindow(Windows.HWnd hWnd);

		[LinkName("UnregisterClassW")]
		static extern Windows.IntBool UnregisterClass(char16* className, Windows.HInstance hInstance);

		public ~this()
		{
			if(!DestroyWindow(_windowHandle))
			{
				HResult res = (.)GetLastError();
				Log.EngineLogger.Error($"Failed to destroy window: Message ({(int)res}): {res}");
			}

			UnregisterClass(WindowClassName.ToScopedNativeWChar!(), _instanceHandle);
		}

		private void Init(WindowDescription desc)
		{
			Log.EngineLogger.Trace($"Creating window \"{desc.Title}\" ({desc.Width}, {desc.Height})...");

			_instanceHandle = (.)GetModuleHandleW(null);

			_windowClass = .();
			_windowClass.Style = .HorizontalRedrawOnChange | .VerticalRedrawOnChange;
			_windowClass.WindowProcedure = => MessageHandler;
			_windowClass.HInstance = (.)_instanceHandle;

			if (desc.Icon.Ptr != null)
				_windowClass.Icon = LoadImageW(0, desc.Icon.ToScopedNativeWChar!(), .Icon, 0, 0, .LoadFromFile);
			else
				_windowClass.Icon = 0;

			_windowClass.Cursor = LoadCursorW(0, IDC_ARROW);
			_windowClass.BackgroundBrush = (HBRUSH)SystemColor.WindowFrame;
			_windowClass.ClassName = WindowClassName.ToScopedNativeWChar!();

			if (RegisterClassExW(ref _windowClass) == 0)
			{
				uint32 lastError = GetLastError();
				Log.EngineLogger.Error($"Failed to register window class. Message({(int)lastError}): {(HResult)lastError}");
				Runtime.FatalError("Failed to register window class");
			}

			_windowHandle = CreateWindowExW(.None, _windowClass.ClassName, desc.Title.ToScopedNativeWChar!(), .WS_OVERLAPPEDWINDOW | .WS_VISIBLE,
				CW_USEDEFAULT, CW_USEDEFAULT, desc.Width, desc.Height, 0, 0, (.)_instanceHandle, null);
			
			_graphicsContext = new GraphicsContext(_windowHandle);
			_graphicsContext.Init();

			void* myPtr = Internal.UnsafeCastToPtr(this);
			SetWindowLongPtrW(_windowHandle, GWL_USERDATA, (int)myPtr);

			LoadWindowRectangle();

			Log.EngineLogger.Trace($"Created window \"{Title}\" ({Width}, {Height})");

			if(Input.RawInput)
			{
				InitRawInput();
			}
		}

		[CLink, CallingConvention(.Stdcall)]
		static extern IntBool RegisterRawInputDevices(RAWINPUTDEVICE* rawInputDevices, uint32 numDevices, uint32 size);

		private void InitRawInput()
		{
			RAWINPUTDEVICE[1] Rid;
			        
			Rid[0].UsagePage = 0x01;          // HID_USAGE_PAGE_GENERIC
			Rid[0].Usage = 0x02;              // HID_USAGE_GENERIC_MOUSE
			Rid[0].Flags = 0;//RIDEV_NOLEGACY;    // adds mouse and also ignores legacy mouse messages
			Rid[0].Target = 0;
			/*
			Rid[1].UsagePage = 0x01;          // HID_USAGE_PAGE_GENERIC
			Rid[1].Usage = 0x06;              // HID_USAGE_GENERIC_KEYBOARD
			Rid[1].Flags = RIDEV_NOLEGACY;    // adds keyboard and also ignores legacy keyboard messages
			Rid[1].Target = 0;
			*/
			if (!RegisterRawInputDevices(&Rid, Rid.Count, sizeof(RAWINPUTDEVICE)))
			{
				DirectX.Common.HResult errorCode = (.)GetLastError();
				Log.EngineLogger.Error($"Failed to register raw input devices. Message({(int32)errorCode}):{errorCode}");
				// Disable raw input
				Input.RawInput = false;
			}
			else
			{
				Log.EngineLogger.Trace($"Registered raw input devices.");
			}
		}

		private bool _isResizingOrMoving;
		private bool _isMinimized;

		[CLink]
		static extern IntBool IsWindowUnicode(HWND whnd);

		private static LRESULT MessageHandler(HWND hwnd, uint32 uMsg, WPARAM wParam, LPARAM lParam)
		{
			void* windowPtr = (void*)GetWindowLongPtrW(hwnd, GWL_USERDATA);
			Window window = (Window)Internal.UnsafeCastToObject(windowPtr);
			
			if (window == null)
			{
				return DefWindowProcW(hwnd, uMsg, wParam, lParam);
			}

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
						SplitHighAndLowOrder!(lParam, out window._clientRect.Width, out window._clientRect.Height);

						window._graphicsContext.SwapChain.Width = (.)window._clientRect.Width;
						window._graphicsContext.SwapChain.Height = (.)window._clientRect.Height;

						window._graphicsContext.SwapChain.ApplyChanges();

						WindowResizeEvent event = scope WindowResizeEvent(window._clientRect.Width, window._clientRect.Height, window._isResizingOrMoving);
						window._eventCallback(event);
					}
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

				////
				//// Keyboard input
				////

			case WM_KEYDOWN:
				{
					var event = scope KeyPressedEvent((Key)wParam, (int32)lParam & 0xFFFF);
					window._eventCallback(event);
				}
			case WM_KEYUP:
				{
					var event = scope KeyReleasedEvent((Key)wParam);
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
				// Raw Input
			case 0x00FF: //WM_INPUT
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
								int32 movementX = raw.Data.Mouse.lLastX;
								int32 movementY = raw.Data.Mouse.lLastY;
					
								// TODO: raw.Data.Mouse.usFlags defines whether movement is abosulte, relative, etc...
								Input.[Friend]rawMovement += .(movementX, movementY);
								/*
								var event = scope MouseMovedEvent(movementX, movementY);
								window._eventCallback(event);
								
								// Convert button transition flags to a more manageable type
								var buttonTransitions = (RawMouseButtonTransition)raw.Data.Mouse.DUMMYUNIONNAME.DUMMYSTRUCTNAME.usButtonFlags;

								if(buttonTransitions.HasFlag(.LeftDown))
								{
									var buttonEvent = scope MouseButtonPressedEvent(.LeftButton);
									window._eventCallback(buttonEvent);
								}
								else if(buttonTransitions.HasFlag(.LeftUp))
								{
									var buttonEvent = scope MouseButtonReleasedEvent(.LeftButton);
									window._eventCallback(buttonEvent);
								}

								if(buttonTransitions.HasFlag(.RightDown))
								{
									var buttonEvent = scope MouseButtonPressedEvent(.RightButton);
									window._eventCallback(buttonEvent);
								}
								else if(buttonTransitions.HasFlag(.RightUp))
								{
									var buttonEvent = scope MouseButtonReleasedEvent(.RightButton);
									window._eventCallback(buttonEvent);
								}

								if(buttonTransitions.HasFlag(.MiddleDown))
								{
									var buttonEvent = scope MouseButtonPressedEvent(.MiddleButton);
									window._eventCallback(buttonEvent);
								}
								else if(buttonTransitions.HasFlag(.MiddleUp))
								{
									var buttonEvent = scope MouseButtonReleasedEvent(.MiddleButton);
									window._eventCallback(buttonEvent);
								}

								if(buttonTransitions.HasFlag(.XButton1Down))
								{
									var buttonEvent = scope MouseButtonPressedEvent(.XButton1);
									window._eventCallback(buttonEvent);
								}
								else if(buttonTransitions.HasFlag(.XButton1Up))
								{
									var buttonEvent = scope MouseButtonReleasedEvent(.XButton1);
									window._eventCallback(buttonEvent);
								}

								if(buttonTransitions.HasFlag(.XButton2Down))
								{
									var buttonEvent = scope MouseButtonPressedEvent(.XButton2);
									window._eventCallback(buttonEvent);
								}
								else if(buttonTransitions.HasFlag(.XButton2Up))
								{
									var buttonEvent = scope MouseButtonReleasedEvent(.XButton2);
									window._eventCallback(buttonEvent);
								}

								if(buttonTransitions.HasFlag(.MouseWheel))
								{
									int32 rotation = raw.Data.Mouse.DUMMYUNIONNAME.DUMMYSTRUCTNAME.usButtonData / WHEEL_DELTA;
				
									var scrollEvent = scope MouseScrolledEvent(0, rotation);
									window._eventCallback(scrollEvent);
								}

								if(buttonTransitions.HasFlag(.MouseHWheel))
								{
									int32 rotation = raw.Data.Mouse.DUMMYUNIONNAME.DUMMYSTRUCTNAME.usButtonData / WHEEL_DELTA;
				
									var scrollEvent = scope MouseScrolledEvent(rotation, 0);
									window._eventCallback(scrollEvent);
								}
								*/
							}
						}
					}
				}
			}

			return DefWindowProcW(hwnd, uMsg, wParam, lParam);
		}

		enum RawMouseButtonTransition
		{
			LeftDown = 0x0001,
			LeftUp = 0x0002,
			MiddleDown = 0x0010,
			MiddleUp = 0x0020,
			RightDown = 0x0004,
			RightUp = 0x0008,
			XButton1Down = 0x0040,
			XButton1Up = 0x0080,
			XButton2Down = 0x0100,
			XButton2Up = 0x0200,
			MouseWheel = 0x0400,
			MouseHWheel = 0x0800
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
	}
}
#endif