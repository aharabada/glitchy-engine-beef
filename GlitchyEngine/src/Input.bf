using System;
using GlitchyEngine.Events;
using GlitchyEngine.Math;

namespace GlitchyEngine
{
	public static class Input
	{
		public static extern bool IsKeyPressed(int32 keycode);
		public static extern bool IsKeyReleased(int32 keycode);
		public static extern bool IsKeyToggled(int32 keycode);

		public static extern bool IsMouseButtonPressed(MouseButton button);
		public static extern bool IsMouseButtonReleased(MouseButton button);
		
		public static extern int32 GetMouseX();
		public static extern int32 GetMouseY();

		public static extern Point GetMousePosition();
	}
}
