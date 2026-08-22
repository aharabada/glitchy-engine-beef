using System;

namespace GlitchyEditor.CodeEditors;

interface IIdeAdapter
{
	/// Opens the current script solution and the specified script file in the IDE. Allows to specify a line number and a column that the cursor will be moved to.
	/// @param fileName The absolute path to the script file. Can be null to just open the script project (Note: the same thing can be achieved by using @see OpenScriptProject).
	/// @param lineNumber The line number that the cursor will be placed at (1-based, so 1 is first line).
	/// @param lineNumber The column number that the cursor will be placed at (1-based, so 1 is the start of the line).
	void OpenScript(StringView fileName, int lineNumber = 0, int columnNumber = 0);

	/// Opens the current script solution in the IDE.
	void OpenScriptProject();
}
