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
		[CLink, CallingConvention(.Stdcall)]
		static extern int16 GetKeyState(int32 keycode);
		
		public override static bool IsKeyPressed(int32 keycode)
		{
			int16 state = GetKeyState(keycode);
			return state < 0;
		}
		
		public override static bool IsKeyReleased(int32 keycode)
		{
			int16 state = GetKeyState(keycode);
			return state >= 0;
		}
		
		public override static bool IsKeyToggled(int32 keycode)
		{
			int16 state = GetKeyState(keycode);
			return (state & 0x1) == 1;
		}

		private static mixin MouseButtonToKeyCode(MouseButton button)
		{
			int32 keycode;
			switch(button)
			{
			case .LeftButton:
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
			int16 state = GetKeyState(MouseButtonToKeyCode!(button));
			return state < 0;
		}

		public override static bool IsMouseButtonReleased(MouseButton button)
		{
			int16 state = GetKeyState(MouseButtonToKeyCode!(button));
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
	}
}
