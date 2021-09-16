using System;
using GlitchyEngine;

namespace GlitchyEditor
{
	class EditorApp : Application
	{
		public this()
		{
			PushLayer(new EditorLayer());
		}

		[Export, LinkName("CreateApplication")]
		public static Application CreateApplication()
		{
			return new EditorApp();
		}
	}
}
