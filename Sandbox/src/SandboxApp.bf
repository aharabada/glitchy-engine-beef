using System;
using GlitchyEngine;
using GlitchyEngine.Events;
using System.Diagnostics;
using GlitchLog;
using GlitchyEngine.ImGui;
using ImGui;

namespace Sandbox
{
	class ExampleLayer : Layer
	{
		[AllowAppend]
		public this() : base("Example") {  }

		public override void Update(GameTime gameTime)
		{
			if(Input.IsKeyPressed(.Tab))
				Log.ClientLogger.Info("Tab key is pressed!");
		}

		public override void OnEvent(Event event)
		{
			Log.ClientLogger.Trace($"{event}");

			EventDispatcher dispatcher = scope EventDispatcher(event);

			dispatcher.Dispatch<ImGuiRenderEvent>(scope (e) => OnImGuiRender(e));
		}

		private bool OnImGuiRender(ImGuiRenderEvent e)
		{
			ImGui.Begin("Test");

			ImGui.End();

			return false;
		}
	}

	class SandboxApp : Application
	{
		public this()
		{
			PushLayer(new ExampleLayer());
		}

		[Export, LinkName("CreateApplication")]
		public static Application CreateApplication()
		{
			return new SandboxApp();
		}
	}
}
