#if BF_PLATFORM_WINDOWS

using DirectX.Windows;
using DirectX.Windows.Winuser;
using DirectX.Windows.Winuser.RawInput;
using DirectX.Windows.VirtualKeyCodes;
using System;
using System.Interop;
using GlitchyEngine.Events;
using GlitchyEngine.Math;

using static System.Windows;

namespace GlitchyEngine
{
	/// Windows (WinApi) specific implementation of the Input-class
	extension Input
	{
		//[CLink, CallingConvention(.Stdcall)]
		//static extern int16 GetKeyState(int32 keycode);
		[CLink, CallingConvention(.Stdcall)]
		static extern IntBool GetCursorPos(out int2 p);
		[CLink, CallingConvention(.Stdcall)]
		static extern IntBool SetCursorPos(c_int x, c_int y);
		[CLink, CallingConvention(.Stdcall)]
		static extern IntBool ScreenToClient(HWnd hWnd, ref int2 p);
		[CLink, CallingConvention(.Stdcall)]
		static extern IntBool ClientToScreen(HWnd hWnd, ref int2 p);

		[Import("user32.lib"), CLink]
		public static extern IntBool RegisterRawInputDevices(RAWINPUTDEVICE* pRawInputDevices, uint32 uiNumDevices, uint32 cbSize);

		public static void RegisterRIDs()
		{
			RAWINPUTDEVICE rid;
			        
			rid.UsagePage = 0x01; 
			rid.Usage = 0x02; 
			rid.Flags = 0;
			rid.Target = 0;

			if(RegisterRawInputDevices(&rid, 1, sizeof(RAWINPUTDEVICE)) == 0)
			{
				Log.EngineLogger.Error("Failed to register raw input devices: {0}", GetLastError());
				Log.EngineLogger.AssertDebug(false, "Failed to register raw input device.");
			}
		}

		/// Represents the state of the input devices on the windows platform (WinApi that is).
		struct WindowsInputState
		{
			public int8[256] KeyStates;
			public int2 CursorPosition;
			public int2 CursorPositionDifference;
			public int2 RawCursorMovement;
		}

		static WindowsInputState[2] IputStates;

		static WindowsInputState* CurrentState = &IputStates[0];
		static WindowsInputState* LastState = &IputStates[1];

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
			int8 state = LastState.KeyStates[(int)keycode];
			return state < 0;
		}
		
		public override static bool WasKeyReleased(Key keycode)
		{
			int8 state = LastState.KeyStates[(int)keycode];
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

		public override static bool IsMouseButtonPressing(MouseButton button) => IsMouseButtonPressed(button) && WasMouseButtonReleased(button);
		
		public override static bool IsMouseButtonReleasing(MouseButton button) => IsMouseButtonReleased(button) && WasMouseButtonPressed(button);
		
		public override static int2 GetMousePosition() => CurrentState.CursorPosition;

		public override static int2 GetMouseMovement() => CurrentState.CursorPositionDifference;
		
		public override static int2 GetRawMouseMovement() => CurrentState.RawCursorMovement;

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

		public override static int2 GetLastMousePosition() => LastState.CursorPosition;
		
		public override static int2 GetLastMouseMovement() => LastState.CursorPositionDifference;
		
		public override static int2 GetLastRawMouseMovement() => LastState.RawCursorMovement;

		public override static int32 GetLastMouseX() => LastState.CursorPosition.X;

		public override static int32 GetLastMouseY() => LastState.CursorPosition.Y;

		public override static void SetMousePosition(int2 pos)
		{
			HWnd windowHandle = (HWnd)(int)Application.Get().MainWindow.NativeWindow;

			var pos;

			// TODO: can fail
			ClientToScreen(windowHandle, ref pos);

			SetCursorPos(pos.X, pos.Y);
		}

		public override static void Init()
		{
			RegisterRIDs();
		}

		//public override 

		public override static void Impl_NewFrame()
		{
			Window window = Application.Get().MainWindow;

			Debug.Profiler.ProfileFunction!();

			Swap!(CurrentState, LastState);
			
			// Get current keyboard state
			if(DirectX.Windows.Winuser.GetKeyboardState((uint8*)&CurrentState.KeyStates) == 0)
			{
				DirectX.Common.HResult errorCode = (.)GetLastError();
				Log.EngineLogger.Error($"Failed to get keyboard state. Message({(int32)errorCode}){errorCode}:");
			}

			// Get the current mouse position
			if (GetCursorPos(out CurrentState.CursorPosition) != 0)
			{
				HWnd windowHandle = (HWnd)(int)window.NativeWindow;
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

			CurrentState.RawCursorMovement = window.[Friend]_rawMouseMovementAccumulator;

			if (Mouse.LockedPosition == null)
			{
				// Calculate cursor movement
				CurrentState.CursorPositionDifference = CurrentState.CursorPosition - LastState.CursorPosition;
			}
			else
			{
				// Calculate cursor movement
				CurrentState.CursorPositionDifference = CurrentState.CursorPosition - Mouse.LockedPosition.Value;
				CurrentState.CursorPosition = Mouse.LockedPosition.Value;

			}
		}

		public override static void Impl_EndFrame()
		{
			Application.Get().MainWindow.[Friend]_rawMouseMovementAccumulator = .Zero;
		}
	}
}

#endif
