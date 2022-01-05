using System;
using static System.Compiler;

namespace GlitchyEngine.Generators
{
	public class NewStructGenerator : Generator
	{
		public override String Name => "New Struct";
		
		public override void InitUI()
		{
			AddEdit("name", "Struct Name", "");
		}

		public override void Generate(String outFileName, String outText, ref Flags generateFlags)
		{
			var name = mParams["name"];
			if (name.EndsWith(".bf", .OrdinalIgnoreCase))
				name.RemoveFromEnd(3);
			outFileName.Append(name);
			outText.AppendF(
				$"""
				namespace {Namespace}
				{{
					struct {name}
					{{
					}}
				}}
				""");
		}
	}
}