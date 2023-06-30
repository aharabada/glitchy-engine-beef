using System;
using GlitchyEngine.Events;
using GlitchyEngine.Math;
using System.Collections;
using ImGui;

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
		
		// TODO: Should Input be able to set mousepos?
		public static extern void SetMousePosition(int2 pos);

		public static extern bool IsMouseButtonPressed(MouseButton button);
		public static extern bool IsMouseButtonReleased(MouseButton button);
		public static extern bool IsMouseButtonPressing(MouseButton button);
		public static extern bool IsMouseButtonReleasing(MouseButton button);
		public static extern int2 GetMousePosition();
		public static extern int2 GetMouseMovement();
		public static extern int2 GetRawMouseMovement();
		public static extern int32 GetMouseX();
		public static extern int32 GetMouseY();
		
		public static extern bool WasMouseButtonPressed(MouseButton button);
		// public static extern bool WasMouseButtonPressing(MouseButton button);
		public static extern bool WasMouseButtonReleased(MouseButton button);
		//public static extern bool WasMouseButtonReleasing(MouseButton button);
		public static extern int2 GetLastMousePosition();
		public static extern int2 GetLastMouseMovement();
		public static extern int2 GetLastRawMouseMovement();
		public static extern int32 GetLastMouseX();
		public static extern int32 GetLastMouseY();

		public static extern void Init();

		public static void NewFrame()
		{
			[Inline]
			Impl_NewFrame();

			Mouse.NewFrame();

			[Inline]
			Impl_EndFrame();
		}

		public static extern void Impl_NewFrame();
		public static extern void Impl_EndFrame();

		public static void ImGuiDebugDraw()
		{
			if (ImGui.Begin("Input"))
			{
				ImGui.TextUnformatted("Last Mouse state");

				ImGui.Columns(2);

				ImGui.TextUnformatted("Position");
				ImGui.NextColumn();
				ImGui.Text($"{GetLastMousePosition()}");
				ImGui.NextColumn();

				ImGui.TextUnformatted("Movement");
				ImGui.NextColumn();
				ImGui.Text($"{GetLastMouseMovement()}");
				ImGui.NextColumn();

				ImGui.TextUnformatted("RawMovement");
				ImGui.NextColumn();
				ImGui.Text($"{GetLastRawMouseMovement()}");
				ImGui.NextColumn();
				
				ImGui.Columns(1);

				ImGui.Separator();

				ImGui.TextUnformatted("Current Mouse state");

				ImGui.Columns(2);

				ImGui.TextUnformatted("Position");
				ImGui.NextColumn();
				ImGui.Text($"{GetMousePosition()}");
				ImGui.NextColumn();

				ImGui.TextUnformatted("Movement");
				ImGui.NextColumn();
				ImGui.Text($"{GetMouseMovement()}");
				ImGui.NextColumn();
				
				ImGui.TextUnformatted("RawMovement");
				ImGui.NextColumn();
				ImGui.Text($"{GetRawMouseMovement()}");
				ImGui.NextColumn();

				ImGui.Columns(1);
			}

			ImGui.End();
		}
	}

	public static class Mouse
	{
		private static append List<(int2 Position, int Hash)> _lockPositions = .();
		
		public static void LockCurrentPosition(int hash)
		{
			LockPosition(Input.GetMousePosition(), hash);
		}

		public static void LockPosition(int2 pos, int hash)
		{
			for (var entry in _lockPositions)
			{
				if (entry.Hash == hash)
				{
					entry.Position = pos;
					break;
				}
			}

			_lockPositions.Add((pos, hash));
		}

		public static void UnlockPosition(int hash)
		{
			for (var entry in _lockPositions)
			{
				if (entry.Hash == hash)
				{
					@entry.Remove();
					break;
				}
			}

			//Log.EngineLogger.AssertDebug(false, "No mouse lock position with hash found.");
		}

		public static int2? LockedPosition;

		public static void NewFrame()
		{
			if (_lockPositions.Count > 0)
			{
				var position = _lockPositions.Back.Position;

				LockedPosition = position;

				Input.SetMousePosition(position);
			}
			else
			{
				LockedPosition = null;
			}
		}
	}
}
