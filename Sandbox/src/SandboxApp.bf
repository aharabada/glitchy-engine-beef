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
			Log.ClientLogger.Info("ExampleLayer.Update");

			// Just for temporary vsyncing
			// Todo: remove
			//DwmFlush();
		}

		[CLink, Import("Dwmapi.lib")]
		static extern void DwmFlush();

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