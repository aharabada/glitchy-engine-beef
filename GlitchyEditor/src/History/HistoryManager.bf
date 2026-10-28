using System.Collections;
using ImGui;
using System;
namespace GlitchyEditor.History;

/// Manages the undo and redo history.
class HistoryManager
{
	private append List<IHistorizableCommand> _undoHistory = .() ~ ClearAndDeleteItems!(_);
	private append List<IHistorizableCommand> _redoHistory = .() ~ ClearAndDeleteItems!(_);

	/// Adds the given command to the history and executes it.
	public void Do(IHistorizableCommand command)
	{
		_redoHistory.ClearAndDeleteItems();

		_undoHistory.Add(command);

		command.Do();
	}

	/// Reverts the last command and puts it onto the redo stack.
	public bool Undo()
	{
		if (_undoHistory.IsEmpty)
		{
			return false;
		}

		IHistorizableCommand command = _undoHistory.PopBack();

		command.Undo();

		_redoHistory.Add(command);

		return true;
	}

	/// Reapplies the last reverted command and puts it onto the undo stack.
	public bool Redo()
	{
		if (_redoHistory.IsEmpty)
		{
			return false;
		}

		IHistorizableCommand command = _redoHistory.PopBack();

		command.Do();

		_undoHistory.Add(command);

		return true;
	}

	public void DrawDebugUi()
	{
		if (ImGui.Begin("History"))
		{
			ImGui.BeginDisabled(_undoHistory.IsEmpty);

			if (ImGui.Button("Undo"))
			    Undo();

			ImGui.EndDisabled();

			ImGui.SameLine();
			
			ImGui.BeginDisabled(_redoHistory.IsEmpty);

			if (ImGui.Button("Redo"))
			    Redo();

			ImGui.EndDisabled();

			float spacing = ImGui.GetStyle().ItemSpacing.y;
			float height = (ImGui.GetContentRegionAvail().y - spacing) * 0.5f;

		    String buffer = scope .();

		    if (ImGui.BeginChild("UndoStack", .(0, height), .Border))
		    {
		        ImGui.TextUnformatted("Undo stack:");
		        ImGui.Separator();

		        for (IHistorizableCommand command in _undoHistory)
		        {
		            buffer.Clear();
		            command.ToString(buffer);

		            ImGui.TextUnformatted(buffer);
		            ImGui.Separator();
		        }
		    }
		    ImGui.EndChild();

		    if (ImGui.BeginChild("RedoStack", .(0, height), .Border))
		    {
		        ImGui.TextUnformatted("Redo stack:");
		        ImGui.Separator();

		        for (IHistorizableCommand command in _redoHistory)
		        {
		            buffer.Clear();
		            command.ToString(buffer);

		            ImGui.TextUnformatted(buffer);
		            ImGui.Separator();
		        }
		    }

		    ImGui.EndChild();
		}
		ImGui.End();
	}
}
