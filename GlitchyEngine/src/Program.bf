using System;

namespace GlitchyEngine
{
	class Program
	{
		[LinkName("CreateApplication")]
		static extern Application CreateApplication();

		public static int Main(String[] args)
		{
			var app = CreateApplication();

			app.Run();

			delete app;

			return 0;
		}
	}
}
