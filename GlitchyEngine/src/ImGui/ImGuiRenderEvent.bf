using GlitchyEngine.Events;

namespace GlitchyEngine.Events
{
	extension EventType
	{
		case ImGuiRender;
	}
}

namespace GlitchyEngine.ImGui
{
	public class ImGuiRenderEvent : Event, IEvent
	{
		public override EventType EventType => .ImGuiRender;

		public override EventCategory Category => .Application;

		public override System.StringView Name => "ImGuiRender";

		public static EventType StaticType => .ImGuiRender;
	}
}
