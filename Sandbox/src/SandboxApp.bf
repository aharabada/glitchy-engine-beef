using System;
using GlitchyEngine;
using GlitchyEngine.Events;
using System.Diagnostics;
using GlitchLog;
using GlitchyEngine.ImGui;

namespace Sandbox
{
	class ExampleLayer : Layer
	{
		[AllowAppend]
		public this() : base("Example") {  }

		public override void Update(GameTime gameTime)
		{
		}

		public override void OnEvent(Event event)
		{
			Log.ClientLogger.Trace("{}", event);
		}
	}

	class SandboxApp : Application
	{
		public this()
		{
			PushLayer(new ExampleLayer());
			PushOverlay(new ImGuiLayer());
		}

		[Export, LinkName("CreateApplication")]
		public static Application CreateApplication()
		{
			return new SandboxApp();
		}
	}
}
