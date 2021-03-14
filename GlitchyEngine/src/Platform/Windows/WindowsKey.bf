using System;
using DirectX.Windows.Winuser;
using DirectX.Common;

namespace GlitchyEngine
{
	extension Key
	{
		// Todo: make overriding method
		public void GetKeyName(String strBuffer)
		{
			var scanCode = MapVirtualKeyW((.)this, MAPVK_VK_TO_VSC);

			char16[128] name = ?;
			int result;
			
			switch (this)
			{
			case .Left, .Up, .Right, .Down, .RightControl, .RightAlt,
				 .LeftSuper, .RightSuper, ContextMenu,
				 .Prior, .Next, .End, .Home, .Insert, .Delete, .Divide, .Numlock:
				// set extended flag
				scanCode |= 0x0100;
				fallthrough;
			default:
				result = GetKeyNameTextW((.)(scanCode << 16), &name, name.Count);
			}
			
			if(result == 0)
			{
				HResult error = (.)DirectX.Windows.Kernel32.GetLastError();

				Log.EngineLogger.Error($"Failed to convert keycode {(int)this}({this}) to string. WinAPI error({(int)error}): {error}");

				return;
			}
			
			strBuffer.Append(Span<char16>(&name, result));
		}

		/// Converts the given windows specific virtual key code to a GlitchyEngine Key.
		[Inline]
		internal static Key FromWindowsKeyCode(int32 vKeyCode)
		{
			return (.)vKeyCode;
		}
	}
}
