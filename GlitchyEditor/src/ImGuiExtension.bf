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
	public static Payload<T>? AcceptDragDropPayload<T>(ImGui.DragDropPayloadType type, DragDropFlags flags = .None) where T : struct
	{
		return AcceptDragDropPayload<T>(type.GetName(), flags);
	}

	public static Payload* AcceptDragDropPayload(DragDropPayloadType type, DragDropFlags flags = .None)
	{
		return AcceptDragDropPayload(type.GetName(), flags);
	}

	public static bool SetDragDropPayload(DragDropPayloadType type, void* data, size sz, Cond cond = .None)
	{
		return SetDragDropPayload(type.GetName(), data, sz, cond);
	}

	/// Starts a new row in the table and enters the first column.
	public static bool BeginPropertyTable(char8* name, uint32 tableId)
	{
		return ImGui.BeginTableEx(name, tableId, 2, .SizingStretchSame | .BordersInner | .Resizable);
	}

	/// Starts a new row in the table and enters the first column.
	public static void PropertyTableStartNewRow()
	{
		ImGui.TableNextRow();
		ImGui.TableSetColumnIndex(0);
	}

	/// Starts a new property by creating a new table row, writing the name in the first column and entering the second column.
	public static void PropertyTableStartNewProperty(StringView propertyName)
	{
		PropertyTableStartNewRow();

		PropertyTableName(propertyName);
	}

	public static void PropertyTableName(StringView propertyName)
	{
		bool isFirstTableRow = ImGui.TableGetRowIndex() == 0;

		if (isFirstTableRow)
			ImGui.PushItemWidth(-1);

		ImGui.TextUnformatted(propertyName);

		ImGui.AttachTooltip(propertyName);

		ImGui.TableSetColumnIndex(1);
		
		if (isFirstTableRow)
			ImGui.PushItemWidth(-1);
	}

	public static void PropertyTableStartNewProperty(StringView propertyName, StringView tooltip)
	{
		PropertyTableStartNewProperty(propertyName);
		AttachTooltip(tooltip);
	}
}
