using System;
namespace GlitchyEditor.CodeEditors;

interface IIdeAdapter
{
	static void OpenScript(StringView fileName);

	static void OpenScript(StringView fileName, int lineNumber);

	static void OpenScriptProject();
}
