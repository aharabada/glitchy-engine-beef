using System;

namespace GlitchyEngine.Events
{
	public class MouseMovedEvent : Event, IEvent
	{
		private int32 _mouseX, _mouseY;

		public override EventType EventType => .MouseMoved;

		public override StringView Name => "MouseMoved";

		public override EventCategory Category => .Input | .Mouse;

		public static EventType StaticType => .MouseMoved;

		public int32 PositionX => _mouseX;
		public int32 PositionY => _mouseY;

		public this(int32 x, int32 y)
		{
			_mouseX = x;
			_mouseY = y;
		}

		public override void ToString(String strBuffer)
		{
			strBuffer.AppendF("MouseMovedEvent: Position: ({}, {})", _mouseX, _mouseY);
		}
	}
	
	public class RawMouseMovedEvent : Event, IEvent
	{
		private int32 _mouseX, _mouseY;

		public override EventType EventType => .MouseMoved;

		public override StringView Name => "RawMouseMoved";

		public override EventCategory Category => .Input | .Mouse;

		public static EventType StaticType => .MouseMoved;

		public int32 PositionX => _mouseX;
		public int32 PositionY => _mouseY;

		public this(int32 x, int32 y)
		{
			_mouseX = x;
			_mouseY = y;
		}

		public override void ToString(String strBuffer)
		{
			strBuffer.AppendF("RawMouseMovedEvent: Position: ({}, {})", _mouseX, _mouseY);
		}
	}

	public class MouseScrolledEvent : Event, IEvent
	{
		private int32 _xOffset, _yOffset;

		public override EventType EventType => .MouseScrolled;

		public override StringView Name => "MouseScrolled";

		public override EventCategory Category => .Input | .Mouse;

		public static EventType StaticType => .MouseScrolled;

		public int32 XOffset => _xOffset;
		public int32 YOffset => _yOffset;

		public this(int32 xOffset, int32 yOffset)
		{
			_xOffset = xOffset;
			_yOffset = yOffset;
		}

		public override void ToString(String strBuffer)
		{
			strBuffer.AppendF("MouseScrolledEvent: {}, {}", _xOffset, _yOffset);
		}
	}

	public enum MouseButton
	{
		None = 0,
		LeftButton,
		RightButton,
		MiddleButton,
		XButton1,
		XButton2,
	}

	public abstract class MouseButtonEvent : Event
	{
		protected MouseButton _mouseButton;

		public override EventCategory Category => .Input | .Mouse;

		public MouseButton MouseButton => _mouseButton;

		protected this(MouseButton mouseButton)
		{
			_mouseButton = mouseButton;
		}
	}

	public class MouseButtonPressedEvent : MouseButtonEvent, IEvent
	{
		public override EventType EventType => .MouseButtonPressed;

		public override StringView Name => "MouseButtonPressed";

		public static EventType StaticType => .MouseButtonPressed;

		public this(MouseButton mouseButton) : base(mouseButton) {  }

		public override void ToString(String strBuffer)
		{
			strBuffer.AppendF("MouseButtonPressedEvent: {}", _mouseButton);
		}
	}
	

	public class MouseButtonReleasedEvent : MouseButtonEvent, IEvent
	{
		public override EventType EventType => .MouseButtonReleased;

		public override StringView Name => "MouseButtonReleased";

		public static EventType StaticType => .MouseButtonReleased;

		public this(MouseButton mouseButton) : base(mouseButton) {  }

		public override void ToString(String strBuffer)
		{
			strBuffer.AppendF("MouseButtonReleasedEvent: {}", _mouseButton);
		}
	}
}
