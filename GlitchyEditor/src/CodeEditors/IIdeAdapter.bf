using System;
namespace GlitchyEditor.CodeEditors;

interface IIdeAdapter
{
	void OpenScript(StringView fileName, int lineNumber = 0, int columnNumber = 0);

	void OpenScriptProject();
}
