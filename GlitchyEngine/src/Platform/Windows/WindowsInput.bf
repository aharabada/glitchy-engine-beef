using System;
using GlitchyEngine.Events;
using DirectX.Windows.VirtualKeyCodes;
using DirectX.Windows;
using GlitchyEngine.Math;
using static System.Windows;

namespace GlitchyEngine
{

#if GE_WINDOWS
	/// Windows (WinApi) specific implementation of the Input-class
	extension Input
	{
		internal static bool sUseRawInput = true;

		public override static bool RawInput
		{
			get => sUseRawInput;
			set
			{
				if(sUseRawInput == value)
					return;

				sUseRawInput = value;

				//if(sUseRawInput)
					// TODO: init raw input
			}
		}

		/// Represents the state of the input devices on the windows platform (WinApi that is).
		struct WindowsInputState
		{
			public int8[256] KeyStates;
			public Point CursorPosition;
			public Point CursorPositionDifference;
			public Int32_2 RawMovement;
		}

		static WindowsInputState* CurrentState = new WindowsInputState() ~ delete _;
		static WindowsInputState* LastState = new WindowsInputState() ~ delete _;

		//
		// Current Keyboard state
		//
		public override static bool IsKeyPressed(Key keycode)
		{
			int8 state = CurrentState.KeyStates[(int)keycode];
			return state < 0;
		}
		
		public override static bool IsKeyReleased(Key keycode)
		{
			int8 state = CurrentState.KeyStates[(int)keycode];
			return state >= 0;
		}
		
		public override static bool IsKeyToggled(Key keycode)
		{
			int8 state = CurrentState.KeyStates[(int)keycode];
			return (state & 0x1) == 1;
		}
		
		//
		// Last Keyboard state
		//
		public override static bool WasKeyPressed(Key keycode)
		{
			int8 state = CurrentState.KeyStates[(int)keycode];
			return state < 0;
		}
		
		public override static bool WasKeyReleased(Key keycode)
		{
			int8 state = CurrentState.KeyStates[(int)keycode];
			return state >= 0;
		}
		
		public override static bool WasKeyToggled(Key keycode)
		{
			int8 state = LastState.KeyStates[(int)keycode];
			return (state & 0x1) == 1;
		}
		
		//
		// Keyboard state transition
		//
		public override static bool IsKeyPressing(Key keycode)
		{
			return IsKeyPressed(keycode) && WasKeyReleased(keycode);
		}
		
		public override static bool IsKeyReleasing(Key keycode)
		{
			return IsKeyReleased(keycode) && WasKeyPressed(keycode);
		}

		/// translates the MouseButton-enum to WinApi virtual keycodes
		static mixin MouseButtonToKeyCode(MouseButton button)
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

		//
		// Current Mouse state
		//
		public override static bool IsMouseButtonPressed(MouseButton button)
		{
			int8 state = CurrentState.KeyStates[MouseButtonToKeyCode!(button)];
			return state < 0;
		}

		public override static bool IsMouseButtonReleased(MouseButton button)
		{
			int8 state = CurrentState.KeyStates[MouseButtonToKeyCode!(button)];
			return state >= 0;
		}

		public override static Point GetMousePosition() => CurrentState.CursorPosition;

		public override static int32 GetMouseX() => CurrentState.CursorPosition.X;

		public override static int32 GetMouseY() => CurrentState.CursorPosition.Y;
		
		//
		// Last Mouse state
		//
		public override static bool WasMouseButtonPressed(MouseButton button)
		{
			int8 state = LastState.KeyStates[MouseButtonToKeyCode!(button)];
			return state < 0;
		}

		public override static bool WasMouseButtonReleased(MouseButton button)
		{
			int8 state = LastState.KeyStates[MouseButtonToKeyCode!(button)];
			return state >= 0;
		}

		public override static Point GetLastMousePosition() => LastState.CursorPosition;

		public override static int32 GetLastMouseX() => LastState.CursorPosition.X;

		public override static int32 GetLastMouseY() => LastState.CursorPosition.Y;

		//
		// Mouse state transition
		//
		public override static bool IsMouseButtonPressing(MouseButton button) => IsMouseButtonPressed(button) && WasMouseButtonReleased(button);
		
		public override static bool IsMouseButtonReleasiong(MouseButton button) => IsMouseButtonReleased(button) && WasMouseButtonPressed(button);
		
		public override static Point GetMouseMovement() => CurrentState.CursorPositionDifference;

		public override static Int32_2 GetRawMouseMovement()
		{
			if(sUseRawInput)
			{
				return CurrentState.RawMovement;
			}
			else
			{
				var v = GetMouseMovement();

				return *(Int32_2*)&v;
			}
		}

		//[CLink, CallingConvention(.Stdcall)]
		//static extern int16 GetKeyState(int32 keycode);
		[CLink, CallingConvention(.Stdcall)]
		static extern IntBool GetCursorPos(out Point p);
		[CLink, CallingConvention(.Stdcall)]
		static extern IntBool ScreenToClient(HWnd hWnd, ref Point p);

		internal static Int32_2 rawMovement;

		public override static void NewFrame()
		{
			// Switch last and current states
			var buffer = LastState;
			LastState = CurrentState;
			CurrentState = buffer;

			// Get current keyboard state
			if(DirectX.Windows.Winuser.GetKeyboardState((uint8*)&CurrentState.KeyStates) == 0)
			{
				DirectX.Common.HResult errorCode = (.)GetLastError();
				Log.EngineLogger.Error($"Failed to get keyboard state. Message({(int32)errorCode}){errorCode}:");
			}

			// Get the current mouse position
			if (GetCursorPos(out CurrentState.CursorPosition) != 0)
			{
				HWnd windowHandle = (HWnd)(int)Application.Get().Window.NativeWindow;
				if (ScreenToClient(windowHandle, ref CurrentState.CursorPosition) == 0)
				{
					DirectX.Common.HResult errorCode = (.)GetLastError();
					Log.EngineLogger.Error($"Failed to convert coordinates from screen to client space. Message({(int32)errorCode}){errorCode}:");
				}
			}
			else
			{
				DirectX.Common.HResult errorCode = (.)GetLastError();
				Log.EngineLogger.Error($"Failed to get mouse position. Message({(int32)errorCode}){errorCode}:");
			}

			// Calculate cursor movement
			CurrentState.CursorPositionDifference = CurrentState.CursorPosition - LastState.CursorPosition;
			CurrentState.RawMovement = rawMovement;
			rawMovement = .Zero;
		}
	}
#endif
}
