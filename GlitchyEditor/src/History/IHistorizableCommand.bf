namespace GlitchyEditor.History;

interface IHistorizableCommand
{
	void Do();
	void Undo();
}
