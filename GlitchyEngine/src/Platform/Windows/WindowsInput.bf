using System;
using GlitchyEngine.Events;
using DirectX.Windows.VirtualKeyCodes;
using DirectX.Windows;
using GlitchyEngine.Math;
using static System.Windows;

namespace GlitchyEngine
{
	extension Input
	{
		static int8* LastKeyStates = new int8[256]* ~ delete _;
		static int8* CurrentkeyStates = new int8[256]* ~ delete _;

		[CLink, CallingConvention(.Stdcall)]
		static extern int16 GetKeyState(int32 keycode);
		
		public override static bool IsKeyPressed(Key keycode)
		{
			//int16 state = GetKeyState((.)keycode);
			int8 state = CurrentkeyStates[(int)keycode];
			return state < 0;
		}
		
		public override static bool IsKeyReleased(Key keycode)
		{
			//int16 state = GetKeyState((.)keycode);
			int8 state = CurrentkeyStates[(int)keycode];
			return state >= 0;
		}
		
		public override static bool IsKeyToggled(Key keycode)
		{
			//int16 state = GetKeyState((.)keycode);
			int8 state = CurrentkeyStates[(int)keycode];
			return (state & 0x1) == 1;
		}

		public override static bool WasKeyPressed(Key keycode)
		{
			int8 state = LastKeyStates[(int)keycode];
			return state < 0;
		}
		
		public override static bool WasKeyReleased(Key keycode)
		{
			int8 state = LastKeyStates[(int)keycode];
			return state >= 0;
		}
		
		public override static bool WasKeyToggled(Key keycode)
		{
			int8 state = LastKeyStates[(int)keycode];
			return (state & 0x1) == 1;
		}
		
		public override static bool IsKeyPressing(Key keycode)
		{
			return default;
			//return IsKeyPressed(keycode) && WasKeyReleased(keycode);
		}

		private static mixin MouseButtonToKeyCode(MouseButton button)
		{
			int32 keycode;
			switch(button)
			{
			case MouseButton.LeftButton:
				keycode = VK_LBUTTON;
			case .RightButton:
				keycode = VK_RBUTTON;
			case .MiddleButton:
				keycode = VK_MBUTTON;
			case .XButton1:
				keycode = VK_XBUTTON1;
			case .XButton2:
				keycode = VK_XBUTTON2;
			case default:
				return false;
			}

			keycode
		}

		public override static bool IsMouseButtonPressed(MouseButton button)
		{
			//int16 state = GetKeyState(MouseButtonToKeyCode!(button));
			int8 state = CurrentkeyStates[MouseButtonToKeyCode!(button)];
			return state < 0;
		}

		public override static bool IsMouseButtonReleased(MouseButton button)
		{
			//int16 state = GetKeyState(MouseButtonToKeyCode!(button));
			int8 state = CurrentkeyStates[MouseButtonToKeyCode!(button)];
			return state >= 0;
		}

		[CLink, CallingConvention(.Stdcall)]
		static extern IntBool GetCursorPos(out Point p);
		[CLink, CallingConvention(.Stdcall)]
		static extern IntBool ScreenToClient(HWnd hWnd, ref Point p);

		static mixin GetMousePos()
		{
			Point point;
			if (GetCursorPos(out point))
			{
				HWnd windowHandle = (HWnd)(int)Application.Get().Window.NativeWindow;
				if (ScreenToClient(windowHandle, ref point))
				{
					// Todo: error handling?
				}
			}

			point
		}

		public override static Point GetMousePosition()
		{
			return GetMousePos!();
		}

		public override static int32 GetMouseX()
		{
			return GetMousePos!().X;
		}

		public override static int32 GetMouseY()
		{
			return GetMousePos!().Y;
		}
		
		public override static void NewFrame()
		{
			// Switch last and current keyStates
			int8* buffer = LastKeyStates;
			LastKeyStates = CurrentkeyStates;
			CurrentkeyStates = buffer;

			// Get current keyboard state
			var result = DirectX.Windows.Winuser.GetKeyboardState((uint8*)CurrentkeyStates);

			if(result == 0)
			{
				DirectX.Common.HResult res = (.)GetLastError();

				Log.EngineLogger.Error("Failed to get keyboard state Message({}){}:", (int32)res, res);
			}
		}
	}
}
