using System;

namespace GlitchyEngine.Events
{
	public abstract class KeyEvent : Event
	{
		protected int32 _keyCode;

		[Inline]
		public int32 KeyCode => _keyCode;

		public override EventCategory Category => .Input | .Keyboard

		protected this(int32 keyCode)
		{
			_keyCode = keyCode;
		}
	}

	public class KeyPressedEvent : KeyEvent, IEvent
	{
		private int32 _repeatCount;
		
		public int32 RepeatCount => _repeatCount;

		public override EventType EventType => .KeyPressed;
		public static EventType StaticType => .KeyPressed;

		public override StringView Name => "KeyPressed";

		public this(int32 keyCode, int32 repeatCount) : base(keyCode)
		{
			_repeatCount = repeatCount;
		}

		public override void ToString(String strBuffer)
		{
			strBuffer.AppendF("KeyPressedEvent: {} ({} repeats)", _keyCode, _repeatCount);
		}
	}

	public class KeyReleasedEvent : KeyEvent, IEvent
	{
		public override EventType EventType => .KeyReleased;
		public static EventType StaticType => .KeyReleased;

		public override StringView Name => "KeyReleased";

		public this(int32 keyCode) : base(keyCode) {  }

		public override void ToString(String strBuffer)
		{
			strBuffer.AppendF("KeyReleasedEvent: {}", _keyCode);
		}
	}

	public class KeyTypedEvent : Event, IEvent
	{
		private char16 _char;

		[Inline]
		public char16 Char => _char;

		public override EventCategory Category => .Input | .Keyboard

		public override EventType EventType => .KeyTyped;
		public static EventType StaticType => .KeyTyped;
		
		public override StringView Name => "KeyTyped";

		public this(char16 char)
		{
			_char = char;
		}

		public override void ToString(String strBuffer)
		{
			strBuffer.AppendF("KeyTypedEvent: {}", _char);
		}
	}
}
