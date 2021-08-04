using System;
namespace GlitchyEngine.Events
{
	public enum EventType
	{
		None = 0,
		WindowClose, WindowResize, WindowFocus, WindowLostFocus, WindowMoved, WindowActivated, WindowDeactivated,
		AppTick, AppUpdate, AppRender,
		KeyPressed, KeyReleased, KeyTyped,
		MouseButtonPressed, MouseButtonReleased, MouseMoved, MouseScrolled
	}

	public enum EventCategory
	{
		None = 0,
		Application = 1 << 0,
		Input 		= 1 << 1,
		Keyboard	= 1 << 2,
		Mouse		= 1 << 3,
		MouseButton	= 1 << 4
	}

	public interface IEvent
	{
		static EventType StaticType {get;}
	}

	public abstract class Event
	{
		protected bool _handled;

		public bool Handled
		{
			[Inline]
			get => _handled;
			[Inline]
			set => _handled = value;
		}

		public abstract EventType EventType {get;}
		public abstract StringView Name {get;}
		public abstract EventCategory Category {get;}

		[Inline]
		public bool IsInCategory(EventCategory category) => (Category & category) > 0;

		public override void ToString(String strBuffer)
		{
			strBuffer.Append(Name);
		}
	}

	public struct EventDispatcher
	{
		private Event _event;

		typealias EventFn<T> = function bool(T);

		private delegate bool EventFunction<T>(T event) where T : Event;

		public this(Event event)
		{
			_event = event;
		}

		public bool Dispatch<T>(EventFunction<T> eventFunction) where T : Event, IEvent
		{
			if(_event.EventType == T.StaticType)
			{
				_event.[Friend]_handled = eventFunction((T)_event);
				return true;
			}
			return false;
		}
	}
}
