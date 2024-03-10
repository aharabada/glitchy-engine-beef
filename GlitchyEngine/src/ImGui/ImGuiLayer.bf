using System;
using ImGui;
using GlitchyEngine.Events;
using ImGuizmo;
using GlitchyEngine.Renderer;
using System.IO;

using internal ImGui;

#if GE_GRAPHICS_DX11

using GlitchyEngine.Platform.DX11;
using GlitchyEngine.Math;
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

		private void LoadFont()
		{
			var settings = Application.Instance.Settings.ImGuiSettings;
			
			ImGui.GetIO().Fonts.Clear();

			Stream fontFile = Application.Instance.ContentManager.GetStream(settings.FontName);

			if (fontFile != null)
			{
				// We need to use ImGuis memory allocator because ImGui takes ownership
				uint8* fontData = (uint8*)ImGui.MemAlloc((uint64)fontFile.Length);
				var result = fontFile.TryRead(Span<uint8>(fontData, fontFile.Length));

				if (result case .Err)
					Log.EngineLogger.Error($"Failed to load font \"{settings.FontName}\" from stream.");

				ImGui.GetIO().Fonts.AddFontFromMemoryTTF(fontData, (int32)fontFile.Length, settings.FontSize);
			}
			else
			{
				ImGui.GetIO().Fonts.AddFontDefault();
			}

			ApplyDefaultStyle();

			ImGui.GetIO().Fonts.AddFontDefault();

			delete fontFile;
		}

		private void ApplyDefaultStyle(ImGui.Style* dst = null)
		{
		    ImGui.Style* style = dst ?? ImGui.GetStyle();
		    ImGui.Vec4* colors = &style.Colors;

			style.FrameRounding = 4;
			style.TabRounding = 8;
			style.ScrollbarSize = 20;

			style.WindowMinSize = ImGui.Vec2(100, 100);

			colors[(.)ImGui.Col.WindowBg] = ImGui.Vec4(0.118f, 0.118f, 0.118f, 1.00f);
			colors[(.)ImGui.Col.FrameBg] = ImGui.Vec4(0.289f, 0.387f, 0.533f, 1.00f);
			colors[(.)ImGui.Col.MenuBarBg] = ImGui.Vec4(0.21f, 0.21f, 0.21f, 1.00f);
			colors[(.)ImGui.Col.Header] = ImGui.Vec4(0.267f, 0.295f, 0.329f, 1.00f);
			colors[(.)ImGui.Col.Tab] = ImGui.Vec4(0.473f, 0.519f, 0.580f, 1.00f);
			colors[(.)ImGui.Col.TabUnfocused] = ImGui.Vec4(0.255f, 0.255f, 0.255f, 1.00f);
			colors[(.)ImGui.Col.CheckMark] = ImGui.Vec4(0.851f, 0.863f, 0.900f, 1.00f);
			colors[(.)ImGui.Col.TitleBg] = ImGui.Vec4(0.406f, 0.401f, 0.390f, 1.000f);
			colors[(.)ImGui.Col.TitleBgActive] = ImGui.Vec4(0.196f, 0.192f, 0.182f, 1.000f);
			
		    /*colors[(.)ImGui.Col.Text]                   = ImGui.Vec4(0.00f, 0.00f, 0.00f, 1.00f);
			colors[(.)ImGui.Col.TextDisabled]           = ImGui.Vec4(0.60f, 0.60f, 0.60f, 1.00f);
			colors[(.)ImGui.Col.WindowBg]               = ImGui.Vec4(0.94f, 0.94f, 0.94f, 1.00f);
			colors[(.)ImGui.Col.ChildBg]                = ImGui.Vec4(0.00f, 0.00f, 0.00f, 0.00f);
			colors[(.)ImGui.Col.PopupBg]                = ImGui.Vec4(1.00f, 1.00f, 1.00f, 0.98f);
			colors[(.)ImGui.Col.Border]                 = ImGui.Vec4(0.00f, 0.00f, 0.00f, 0.30f);
			colors[(.)ImGui.Col.BorderShadow]           = ImGui.Vec4(0.00f, 0.00f, 0.00f, 0.00f);
			colors[(.)ImGui.Col.FrameBg]                = ImGui.Vec4(1.00f, 1.00f, 1.00f, 1.00f);
			colors[(.)ImGui.Col.FrameBgHovered]         = ImGui.Vec4(0.26f, 0.59f, 0.98f, 0.40f);
			colors[(.)ImGui.Col.FrameBgActive]          = ImGui.Vec4(0.26f, 0.59f, 0.98f, 0.67f);
			colors[(.)ImGui.Col.TitleBg]                = ImGui.Vec4(0.96f, 0.96f, 0.96f, 1.00f);
			colors[(.)ImGui.Col.TitleBgActive]          = ImGui.Vec4(0.82f, 0.82f, 0.82f, 1.00f);
			colors[(.)ImGui.Col.TitleBgCollapsed]       = ImGui.Vec4(1.00f, 1.00f, 1.00f, 0.51f);
			colors[(.)ImGui.Col.MenuBarBg]              = ImGui.Vec4(0.86f, 0.86f, 0.86f, 1.00f);
			colors[(.)ImGui.Col.ScrollbarBg]            = ImGui.Vec4(0.98f, 0.98f, 0.98f, 0.53f);
			colors[(.)ImGui.Col.ScrollbarGrab]          = ImGui.Vec4(0.69f, 0.69f, 0.69f, 0.80f);
			colors[(.)ImGui.Col.ScrollbarGrabHovered]   = ImGui.Vec4(0.49f, 0.49f, 0.49f, 0.80f);
			colors[(.)ImGui.Col.ScrollbarGrabActive]    = ImGui.Vec4(0.49f, 0.49f, 0.49f, 1.00f);
			colors[(.)ImGui.Col.CheckMark]              = ImGui.Vec4(0.26f, 0.59f, 0.98f, 1.00f);
			colors[(.)ImGui.Col.SliderGrab]             = ImGui.Vec4(0.26f, 0.59f, 0.98f, 0.78f);
			colors[(.)ImGui.Col.SliderGrabActive]       = ImGui.Vec4(0.46f, 0.54f, 0.80f, 0.60f);
			colors[(.)ImGui.Col.Button]                 = ImGui.Vec4(0.26f, 0.59f, 0.98f, 0.40f);
			colors[(.)ImGui.Col.ButtonHovered]          = ImGui.Vec4(0.26f, 0.59f, 0.98f, 1.00f);
			colors[(.)ImGui.Col.ButtonActive]           = ImGui.Vec4(0.06f, 0.53f, 0.98f, 1.00f);
			colors[(.)ImGui.Col.Header]                 = ImGui.Vec4(0.26f, 0.59f, 0.98f, 0.31f);
			colors[(.)ImGui.Col.HeaderHovered]          = ImGui.Vec4(0.26f, 0.59f, 0.98f, 0.80f);
			colors[(.)ImGui.Col.HeaderActive]           = ImGui.Vec4(0.26f, 0.59f, 0.98f, 1.00f);
			colors[(.)ImGui.Col.Separator]              = ImGui.Vec4(0.39f, 0.39f, 0.39f, 0.62f);
			colors[(.)ImGui.Col.SeparatorHovered]       = ImGui.Vec4(0.14f, 0.44f, 0.80f, 0.78f);
			colors[(.)ImGui.Col.SeparatorActive]        = ImGui.Vec4(0.14f, 0.44f, 0.80f, 1.00f);
			colors[(.)ImGui.Col.ResizeGrip]             = ImGui.Vec4(0.35f, 0.35f, 0.35f, 0.17f);
			colors[(.)ImGui.Col.ResizeGripHovered]      = ImGui.Vec4(0.26f, 0.59f, 0.98f, 0.67f);
			colors[(.)ImGui.Col.ResizeGripActive]       = ImGui.Vec4(0.26f, 0.59f, 0.98f, 0.95f);
			colors[(.)ImGui.Col.Tab]                    = ImGui.Vec4(0.96f, 0.8f, 0.52f, 1.0f);//ImGui.ImLerp(colors[(.)ImGui.Col.Header],       colors[(.)ImGui.Col.TitleBgActive], 0.90f);
			colors[(.)ImGui.Col.TabHovered]             = ImGui.Vec4(0.73f, 0.78f, 0.95f, 1.0f);
			colors[(.)ImGui.Col.TabActive]              = ImGui.ImLerp(colors[(.)ImGui.Col.HeaderActive], colors[(.)ImGui.Col.TitleBgActive], 0.60f);
			colors[(.)ImGui.Col.TabUnfocused]           = ImGui.ImLerp(colors[(.)ImGui.Col.Tab],          colors[(.)ImGui.Col.TitleBg], 0.80f);
			colors[(.)ImGui.Col.TabUnfocusedActive]     = ImGui.ImLerp(colors[(.)ImGui.Col.TabActive],    colors[(.)ImGui.Col.TitleBg], 0.40f);
			colors[(.)ImGui.Col.DockingPreview]         = (.)((float4)colors[(.)ImGui.Col.Header] * (float4)ImGui.Vec4(1.0f, 1.0f, 1.0f, 0.7f));
			colors[(.)ImGui.Col.DockingEmptyBg]         = ImGui.Vec4(0.20f, 0.20f, 0.20f, 1.00f);
			colors[(.)ImGui.Col.PlotLines]              = ImGui.Vec4(0.39f, 0.39f, 0.39f, 1.00f);
			colors[(.)ImGui.Col.PlotLinesHovered]       = ImGui.Vec4(1.00f, 0.43f, 0.35f, 1.00f);
			colors[(.)ImGui.Col.PlotHistogram]          = ImGui.Vec4(0.90f, 0.70f, 0.00f, 1.00f);
			colors[(.)ImGui.Col.PlotHistogramHovered]   = ImGui.Vec4(1.00f, 0.45f, 0.00f, 1.00f);
			colors[(.)ImGui.Col.TableHeaderBg]          = ImGui.Vec4(0.78f, 0.87f, 0.98f, 1.00f);
			colors[(.)ImGui.Col.TableBorderStrong]      = ImGui.Vec4(0.57f, 0.57f, 0.64f, 1.00f);   // Prefer using Alpha=1.0 here
			colors[(.)ImGui.Col.TableBorderLight]       = ImGui.Vec4(0.68f, 0.68f, 0.74f, 1.00f);   // Prefer using Alpha=1.0 here
			colors[(.)ImGui.Col.TableRowBg]             = ImGui.Vec4(0.00f, 0.00f, 0.00f, 0.00f);
			colors[(.)ImGui.Col.TableRowBgAlt]          = ImGui.Vec4(0.30f, 0.30f, 0.30f, 0.09f);
			colors[(.)ImGui.Col.TextSelectedBg]         = ImGui.Vec4(0.26f, 0.59f, 0.98f, 0.35f);
			colors[(.)ImGui.Col.DragDropTarget]         = ImGui.Vec4(0.26f, 0.59f, 0.98f, 0.95f);
			colors[(.)ImGui.Col.NavHighlight]           = colors[(.)ImGui.Col.HeaderHovered];
			colors[(.)ImGui.Col.NavWindowingHighlight]  = ImGui.Vec4(0.70f, 0.70f, 0.70f, 0.70f);
			colors[(.)ImGui.Col.NavWindowingDimBg]      = ImGui.Vec4(0.20f, 0.20f, 0.20f, 0.20f);
			colors[(.)ImGui.Col.ModalWindowDimBg]       = ImGui.Vec4(0.20f, 0.20f, 0.20f, 0.35f);*/
		}

		public void ImGuiRender()
		{
			Debug.Profiler.ProfileFunction!();

			if (SettingsInvalid)
			{
				LoadFont();

#if GE_GRAPHICS_DX11
				ImGuiImplDX11.CreateDeviceObjects();
#endif

				SettingsInvalid = false;
			}

			Begin();

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
			
			using (ContextMonitor.Enter())
			{
				ImGuiImplDX11.RenderDrawData(ImGui.GetDrawData());
			}
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
