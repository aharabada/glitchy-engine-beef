using System;
using DirectX.Common;
using DirectX.Windows;
using DirectX.Windows.Winuser;
using DirectX.Windows.Kernel32;
using DirectX.Windows.WindowMessages;

namespace GlitchyEngine.Platform.Windows
{
	[CRepr]
	public struct WindowRectangle
	{
		public int32 X;
		public int32 Y;
		public int32 Width;
		public int32 Height;

		public this() => this = default;

		public this(int32 x, int32 y, int32 width, int32 height)
		{
			X = x;
			Y = y;
			Width = width;
			Height = height;
		}
	}

	public class WindowsWindow : Window
	{
		private Windows.HInstance _instanceHandle;
		private Windows.HWnd _windowHandle;

		private WindowClassExW _windowClass;

		private WindowRectangle _rect;

		public override int32 Width
		{
			get => _rect.Width;

			set
			{
				_rect.Width = value;
				ApplyRectangle();
			}
		}

		public override int32 Height
		{
			get => _rect.Height;

			set
			{
				_rect.Height = value;
				ApplyRectangle();
			}
		}

		private String _title;

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
			Init(desc);
		}

		public ~this()
		{

		}

		private void Init(WindowDescription desc)
		{
			Log.EngineLogger.Trace("Creating window \"{}\" ({}, {})...", desc.Title, desc.Width, desc.Height);

			_instanceHandle = (.)GetModuleHandleW(null);

			_windowClass = .();
			_windowClass.Style = .HorizontalRedrawOnChange | .VerticalRedrawOnChange;
			_windowClass.WindowProcedure = => MessageHandler;
			_windowClass.HInstance = _instanceHandle;

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
				CW_USEDEFAULT, CW_USEDEFAULT, desc.Width, desc.Height, 0, 0, _instanceHandle, null);

			void* myPtr = Internal.UnsafeCastToPtr(this);

			SetWindowLongPtrW(_windowHandle, GWL_USERDATA, (int)myPtr);

			LoadWindowRectangle();
			
			Log.EngineLogger.Trace("Created window \"{}\" ({}, {})", Title, Width, Height);
		}

		private static LRESULT MessageHandler(HWND hwnd, uint32 uMsg, WPARAM wParam, LPARAM lParam)
		{
			void* windowPtr = (void*)GetWindowLongPtrW(hwnd, GWL_USERDATA);
			WindowsWindow window = (WindowsWindow)Internal.UnsafeCastToObject(windowPtr);

			switch(uMsg)
			{
				// Window title changed
			case WM_SETTEXT:
				{
					// Deletes and nulls _title so that it will be reloaded on the next call of Title.get
					delete window._title;
					window._title = null;
				}
				// Window closing
			case WM_CLOSE, WM_DESTROY:
				{
					// Todo: fire closing event!
					PostQuitMessage(0);
					Environment.Exit(0);
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

			_rect.X = rectangle.Left;
			_rect.Y = rectangle.Top;
			_rect.Width = rectangle.Right - rectangle.Left;
			_rect.Height = rectangle.Bottom - rectangle.Top;
		}

		private void ApplyRectangle()
		{
			SetWindowPos(_windowHandle, 0, _rect.X, _rect.Y, _rect.Width, _rect.Height, 0);
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
