using System;
using ImGui;
using GlitchyEngine.Events;
using ImGuizmo;
using GlitchyEngine.Renderer;
using System.IO;

using internal ImGui;

#if GE_GRAPHICS_DX11

using GlitchyEngine.Platform.DX11;
using internal GlitchyEngine.Platform.DX11;

#endif

namespace GlitchyEngine.ImGui
{
	public class ImGuiLayer : Layer
	{
		ImGui.IO* _io;

		public bool SettingsInvalid;

		public this() : base("ImGuiLayer") {  }

		public override void OnAttach()
		{
			Debug.Profiler.ProfileFunction!();

			//ImGuiImplWin32.EnableDpiAwareness();
			Log.EngineLogger.Trace("Initializing ImGui...");

			ImGui.CHECKVERSION();
			ImGui.CreateContext();
			ImGui.StyleColorsDark();

			_io = ImGui.GetIO();
			_io.ConfigFlags |= .NavEnableKeyboard;
			_io.ConfigFlags |= .DockingEnable;
			_io.ConfigFlags |= .ViewportsEnable;

			// Todo: currently broken in ImGui
			//io.ConfigFlags |= .DpiEnableScaleFonts;
			//io.ConfigFlags |= .DpiEnableScaleViewports;

			// When viewports are enabled we tweak WindowRounding/WindowBg so platform windows can look identical to regular ones.
			ImGui.Style* style = ImGui.GetStyle();
			if(_io.ConfigFlags.HasFlag(.ViewportsEnable))
			{
				style.WindowRounding = 0.0f;
				style.Colors[(int)ImGui.Col.WindowBg].w = 1.0f;
			}

#if BF_PLATFORM_WINDOWS
			ImGuiImplWin32.Init(Application.Get().Window.NativeWindow);
#endif

#if GE_GRAPHICS_DX11
			ImGuiImplDX11.Init(NativeDevice, NativeContext);
#endif
		}

		public override void OnDetach()
		{
			Debug.Profiler.ProfileFunction!();
			
#if GE_GRAPHICS_DX11
			ImGuiImplDX11.Shutdown();
#endif

#if BF_PLATFORM_WINDOWS
			ImGuiImplWin32.Shutdown();
#endif

			ImGui.DestroyContext();
		}

		public void Begin()
		{
			Debug.Profiler.ProfileFunction!();

			ImGuiImplDX11.NewFrame();
			ImGuiImplWin32.NewFrame();
			ImGui.NewFrame();
			ImGuizmo.BeginFrame();
		}

		public void ImGuiRender()
		{
			Debug.Profiler.ProfileFunction!();

			if (SettingsInvalid)
			{
				var settings = Application.Get().Settings.ImGuiSettings;
				
				ImGui.GetIO().Fonts.Clear();

				String fullpath = scope String();
				Application.Get().ContentManager.GetFilePath(fullpath, settings.FontName);
				if (File.Exists(fullpath))
				{
					ImGui.GetIO().Fonts.AddFontFromFileTTF(fullpath, settings.FontSize);
				}
				else
				{
					ImGui.GetIO().Fonts.AddFontDefault();
				}

#if GE_GRAPHICS_DX11
				ImGuiImplDX11.CreateDeviceObjects();
#endif

				SettingsInvalid = false;
			}

			Begin();

			ImGui.ShowDemoWindow();

			{
				Debug.Profiler.ProfileScope!("ImGuiRenderEvent");

				var event = scope ImGuiRenderEvent();
				Application.Get().OnEvent(event);
			}

			End();
		}

		public void End()
		{
			Debug.Profiler.ProfileFunction!();

			ImGui.Render();
			
			RenderCommand.SetDepthStencilTarget(null);
			RenderCommand.SetRenderTarget(null);
			RenderCommand.BindRenderTargets();

#if GE_GRAPHICS_DX11
			ImGuiImplDX11.RenderDrawData(ImGui.GetDrawData());
#endif

			ImGui.CleanupFrame();
			
			if(_io.ConfigFlags.HasFlag(.ViewportsEnable))
			{
				ImGui.UpdatePlatformWindows();
				ImGui.RenderPlatformWindowsDefault();
			}
		}
	}
}
