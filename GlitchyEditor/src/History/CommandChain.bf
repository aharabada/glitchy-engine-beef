using System;
using System.Collections;

namespace GlitchyEditor.History;

/// Allows chaining multiple commands into one do/undo action.
class CommandChain : IHistorizableCommand
{
	private append List<IHistorizableCommand> _commands = .();

	public void AddCommand(IHistorizableCommand command)
	{
		_commands.Add(command);
	}

	public void Do()
	{
		for (IHistorizableCommand command in _commands)
		{
			command.Do();
		}
	}

	public void Undo()
	{
		for (IHistorizableCommand command in _commands.Reversed)
		{
			command.Undo();
		}
	}

	public override void ToString(String strBuffer)
	{
		strBuffer.AppendF("Command Chain:\n");

		for (IHistorizableCommand command in _commands)
		{
			command.ToString(strBuffer);
			strBuffer.Append("\n------------\n");
		}
	}
}
