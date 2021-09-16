using System;
using GlitchyEngine;

namespace GlitchyEditor
{
	class SandboxApp : Application
	{
		public this()
		{
			PushLayer(new EditorLayer());
		}

		[Export, LinkName("CreateApplication")]
		public static Application CreateApplication()
		{
			return new SandboxApp();
		}
	}
}
