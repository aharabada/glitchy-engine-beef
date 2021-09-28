using System;
using ImGui;
using GlitchyEngine.Events;
using ImGuizmo;

using internal ImGui;

namespace GlitchyEngine.ImGui
{
	public class ImGuiLayer : Layer
	{
		public this() : base("ImGuiLayer") {  }

		public override void OnAttach()
		{
			//ImGuiImplWin32.EnableDpiAwareness();
			Log.EngineLogger.Trace("Initializing ImGui...");

			ImGui.CHECKVERSION();
			ImGui.CreateContext();
			ImGui.StyleColorsDark();

			ImGui.IO* io = ImGui.GetIO();
			io.ConfigFlags |= .NavEnableKeyboard;
			io.ConfigFlags |= .DockingEnable;
			io.ConfigFlags |= .ViewportsEnable;

			// Todo: currently broken in ImGui
			//io.ConfigFlags |= .DpiEnableScaleFonts;
			//io.ConfigFlags |= .DpiEnableScaleViewports;

			// When viewports are enabled we tweak WindowRounding/WindowBg so platform windows can look identical to regular ones.
			ImGui.Style* style = ImGui.GetStyle();
			if(io.ConfigFlags.HasFlag(.ViewportsEnable))
			{
				style.WindowRounding = 0.0f;
				style.Colors[(int)ImGui.Col.WindowBg].w = 1.0f;
			}

#if GE_WINDOWS
			// Todo: temporary, needs to be platform independent
			ImGuiImplWin32.Init((void*)(uint)(Windows.HWnd)(int)Application.Get().Window.NativeWindow);

			var context = Application.Get().Window.Context;

			ImGuiImplDX11.Init(context.[Friend]nativeDevice, context.[Friend]nativeContext);
#endif
		}

		public override void OnDetach()
		{
			ImGuiImplDX11.Shutdown();
			ImGuiImplWin32.Shutdown();
			ImGui.DestroyContext();
		}

		public override void OnEvent(Event event)
		{
			/*
			EventDispatcher dispatcher = scope EventDispatcher(event);

			dispatcher.Dispatch<WindowResizeEvent>(scope (e) =>
				{
					//ref ImGui.IO io = ref ImGui.GetIO();
					//io.DisplaySize = .(e.Width, e.Height);
					//io.DisplayFramebufferScale = .(1.0f, 1.0f);

					return false;
				});

			dispatcher.Dispatch<MouseMovedEvent>(scope (e) =>
				{
					ref ImGui.IO io = ref ImGui.GetIO();
					io.MousePos = ImGui.Vec2(e.PositionX, e.PositionY);

					return false;
				});

			dispatcher.Dispatch<MouseButtonPressedEvent>(scope (e) =>
				{
					int button = 0;
					switch(e.MouseButton)
					{
					case .LeftButton:
						button = (uint)ImGui.MouseButton.Left;
					case .RightButton:
						button = (uint)ImGui.MouseButton.Right;
					case .MiddleButton:
						button = (uint)ImGui.MouseButton.Middle;
					case .XButton1:
						button = (uint)3;
					case .XButton2:
						button = (uint)4;
					default:
					}

					ref ImGui.IO io = ref ImGui.GetIO();
					io.MouseDown[button] = true;

					return false;
				});

			dispatcher.Dispatch<MouseButtonReleasedEvent>(scope (e) =>
				{
					int button = 0;
					switch(e.MouseButton)
					{
					case .LeftButton:
						button = (uint)ImGui.MouseButton.Left;
					case .RightButton:
						button = (uint)ImGui.MouseButton.Right;
					case .MiddleButton:
						button = (uint)ImGui.MouseButton.Middle;
					case .XButton1:
						button = (uint)3;
					case .XButton2:
						button = (uint)4;
					default:
					}

					ref ImGui.IO io = ref ImGui.GetIO();
					io.MouseDown[button] = false;

					return false;
				});

			dispatcher.Dispatch<MouseScrolledEvent>(scope (e) =>
				{
					ref ImGui.IO io = ref ImGui.GetIO();
					io.MouseWheel += e.YOffset;
					io.MouseWheelH += e.XOffset; // Todo: horizontal mousewheel inverted?!

					return false;
				});

			dispatcher.Dispatch<KeyPressedEvent>(scope (e) =>
				{
					if(e.KeyCode >= (.)256)
						return false;

					ref ImGui.IO io = ref ImGui.GetIO();
					io.KeysDown[(int32)e.KeyCode] = true;
					
					io.KeyCtrl = io.KeysDown[(int32)Key.Control];
					io.KeyShift = io.KeysDown[(int32)Key.Shift];
					io.KeyAlt = io.KeysDown[(int32)Key.Alt];
					io.KeySuper = io.KeysDown[(int32)Key.LeftSuper] || io.KeysDown[(int32)Key.RightSuper];

					return false;
				});

			dispatcher.Dispatch<KeyReleasedEvent>(scope (e) =>
				{
					if(e.KeyCode >= (.)256)
						return false;

					ref ImGui.IO io = ref ImGui.GetIO();
					io.KeysDown[(int32)e.KeyCode] = false;
					
					io.KeyCtrl = io.KeysDown[(int32)Key.Control];
					io.KeyShift = io.KeysDown[(int32)Key.Shift];
					io.KeyAlt = io.KeysDown[(int32)Key.Alt];
					io.KeySuper = io.KeysDown[(int32)Key.LeftSuper] || io.KeysDown[(int32)Key.RightSuper];

					return false;
				});

			dispatcher.Dispatch<KeyTypedEvent>(scope (e) =>
				{
					ref ImGui.IO io = ref ImGui.GetIO();
					io.AddInputCharacterUTF16((uint16)e.Char);

					return false;
				});
			*/
		}

		public void Begin()
		{
			// Todo:
			//var v = DirectX.ImmediateContext;
			//v.OutputMerger.SetRenderTargets(1, &DirectX.BackBufferTarget, null);
			Application.Get().Window.Context.SetRenderTarget(null);
			
			ImGuiImplDX11.NewFrame();
			ImGuiImplWin32.NewFrame();
			ImGui.NewFrame();
			ImGuizmo.BeginFrame();
		}

		bool showDemo = true;
		public void ImGuiRender()
		{
			Begin();

			var event = scope ImGuiRenderEvent();
			Application.Get().OnEvent(event);

			//ImGui.ShowDemoWindow(&showDemo);

			End();
		}

		public void End()
		{
			ImGui.IO* io = ImGui.GetIO();

			let window = Application.Get().Window;
			io.DisplaySize = .(window.Width, window.Height);

			ImGui.Render();
			ImGuiImplDX11.RenderDrawData(ImGui.GetDrawData());

			ImGui.CleanupFrame();

			if(io.ConfigFlags.HasFlag(.ViewportsEnable))
			{
				ImGui.UpdatePlatformWindows();
				ImGui.RenderPlatformWindowsDefault();
			}
		}
	}
}
