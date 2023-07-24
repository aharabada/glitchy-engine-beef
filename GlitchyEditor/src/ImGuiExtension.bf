using System;

namespace ImGui;

enum DragDropPayloadType
{
	case ContentBrowserItem;
	case Entity;

	public String GetName()
	{
		switch (this)
		{
		case .ContentBrowserItem:
			return "CONTENT_BROWSER_ITEM";
		case .Entity:
			return "ENTITY";
		}
	}
}

extension ImGui
{
	public static Payload* AcceptDragDropPayload(DragDropPayloadType type, DragDropFlags flags = .None)
	{
		return AcceptDragDropPayload(type.GetName(), flags);
	}

	public static bool SetDragDropPayload(DragDropPayloadType type, void* data, size sz, Cond cond = .None)
	{
		return SetDragDropPayload(type.GetName(), data, sz, cond);
	}
}
