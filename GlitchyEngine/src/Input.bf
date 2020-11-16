using System;
using GlitchyEngine.Events;
using GlitchyEngine.Math;

namespace GlitchyEngine
{
	public static class Input
	{
		public static extern bool IsKeyPressed(Key keycode);
		public static extern bool IsKeyReleased(Key keycode);
		public static extern bool IsKeyToggled(Key keycode);

		public static extern bool WasKeyPressed(Key keycode);
		public static extern bool WasKeyReleased(Key keycode);
		public static extern bool WasKeyToggled(Key keycode);

		/*
		 * Determines whether or not the key is being pressed down.
		 * @remarks IsKeyPressing(kc) == IsKeyPressed(kc) && !IsKeyReleased(kc)
		 */
		public static extern bool IsKeyPressing(Key keycode);
		/*
		 * Determines whether or not the key is being released down.
		 * @remarks IsKeyReleasing(kc) == !IsKeyPressed(kc) && IsKeyReleased(kc)
		 */
		public static extern bool IsKeyReleasing(Key keycode);

		public static extern bool IsMouseButtonPressed(MouseButton button);
		public static extern bool IsMouseButtonReleased(MouseButton button);
		public static extern Point GetMousePosition();
		public static extern int32 GetMouseX();
		public static extern int32 GetMouseY();
		
		public static extern bool WasMouseButtonPressed(MouseButton button);
		public static extern bool WasMouseButtonReleased(MouseButton button);
		public static extern Point GetLastMousePosition();
		public static extern int32 GetLastMouseX();
		public static extern int32 GetLastMouseY();
		
		public static extern bool IsMouseButtonPressing(MouseButton button);
		public static extern bool IsMouseButtonReleasiong(MouseButton button);
		public static extern Point GetMouseMovement();

		public static extern void NewFrame();
	}
}
