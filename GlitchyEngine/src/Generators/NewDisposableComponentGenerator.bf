using System;
using System.Text;
using static System.Compiler;

namespace GlitchyEngine.Generators
{
	public class NewDisposableComponentGenerator : Generator
	{
		public override String Name => "New Disposable Component";
		
		public override void InitUI()
		{
			AddEdit("name", "Component Name", "");
		}

		public override void Generate(String outFileName, String outText, ref Flags generateFlags)
		{
			var name = mParams["name"];
			if (name.EndsWith(".bf", .OrdinalIgnoreCase))
				name.RemoveFromEnd(3);
			outFileName.Append(name);

			outText.AppendF(
				$"""
				using GlitchyEngine.World;

				namespace {Namespace}
				{{
					struct {name} : IDisposableComponent
					{{
						public void Dispose() mut
						{{
							// TODO: Dispose of the content
						}}
					}}
				}}
				""");
		}
	}
}