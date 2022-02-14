using System;
using GlitchyEngine;
using GlitchyEngine.Events;
using System.Diagnostics;
using GlitchLog;
using GlitchyEngine.ImGui;
using ImGui;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using GlitchyEngine.World;
using System.Collections;
using GlitchyEngine.Content;
using GlitchyEngine.Renderer.Animation;

namespace Sandbox
{
	class SandboxApp : Application
	{
		public this()
		{
			Window.Title = "Single Stage to Highscore";
			Window.SetIcon("content/RocketGame/RocketIcon.ico");

/*#if GAMMA_TEST
			PushLayer(new GammaTestLayer());
#elif SANDBOX_2D
			PushLayer(new ExampleLayer2D());
#else
			PushLayer(new ExampleLayer());
#endif*/
			PushLayer(new GameLayer());
		}

		[Export, LinkName("CreateApplication")]
		public static Application CreateApplication()
		{
			return new SandboxApp();
		}
	}
}
