using System;
using GlitchyEngine;
using System.Diagnostics;
using GlitchLog;

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
