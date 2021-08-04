using System;

namespace GlitchyEngine.Events
{
	public class WindowCloseEvent : Event, IEvent
	{
		public override EventType EventType => .WindowClose;

		public override System.StringView Name => "WindowClose";

		public override EventCategory Category => .Application;

		public static EventType StaticType => .WindowClose;

		public this() {  }

		public override void ToString(String strBuffer)
		{
			strBuffer.Append("WindowCloseEvent");
		}
	}
	
	public class WindowResizeEvent : Event, IEvent
	{
		private int32 _width, _height;
		private bool _isResizing;

		/// The new width of the window.
		public int32 Width => _width;
		/// The new height of the window.
		public int32 Height => _height;
		/*
		 * If true, indicates that the resizing is not finished.
		 */
		public bool IsResizing = _isResizing;

		public override EventType EventType => .WindowResize;

		public override StringView Name => "WindowResize";

		public override EventCategory Category => .Application;

		public static EventType StaticType => .WindowResize;

		public this(int32 width, int32 height, bool isResizing)
		{
			_width = width;
			_height = height;
			_isResizing = isResizing;
		}

		public override void ToString(String strBuffer)
		{
			strBuffer.AppendF("WindowResizeEvent: {}, {} (is resizing: {})", _width, _height, _isResizing);
		}
	}

	public class WindowMoveEvent : Event, IEvent
	{
		private int32 _x, _y;
		private bool _isMoving;

		/// The new x-coordinate of the window.
		public int32 X = _x;
		/// The new y-coordinate of the window.
		public int32 Y = _y;
		/*
		 * If true, indicates that the moving is not finished.
		 */
		public bool IsMoving = _isMoving;

		public override EventType EventType => .WindowMoved;

		public override StringView Name => "WindowMoved";

		public override EventCategory Category => .Application;

		public static EventType StaticType => .WindowMoved;

		public this(int32 x, int32 y, bool isMoving)
		{
			_x = x;
			_y = y;
			_isMoving = isMoving;
		}

		public override void ToString(String strBuffer)
		{
			strBuffer.AppendF("WindowMovedEvent: {}, {} (is moving: {})", _x, _y, _isMoving);
		}
	}

	public class WindowActivateEvent : Event, IEvent
	{
		public override EventType EventType => .WindowMoved;

		public override StringView Name => "WindowActivated";

		public override EventCategory Category => .Application;

		public static EventType StaticType => .WindowActivated;

		public this()
		{
		}

		public override void ToString(String strBuffer)
		{
			strBuffer.AppendF("WindowActivatedEvent");
		}
	}

	public class WindowDeactivateEvent : Event, IEvent
	{
		public override EventType EventType => .WindowMoved;

		public override StringView Name => "WindowDeactivated";

		public override EventCategory Category => .Application;

		public static EventType StaticType => .WindowDeactivated;

		public this()
		{
		}

		public override void ToString(String strBuffer)
		{
			strBuffer.AppendF("WindowDeactivatedEvent");
		}
	}
}
