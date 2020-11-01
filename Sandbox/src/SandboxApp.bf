using System;
using GlitchyEngine;

namespace Sandbox
{
	class SandboxApp : Application
	{
		[Export, LinkName("CreateApplication")]
		public static Application CreateApplication()
		{
			return new SandboxApp();
		}
	}
}
