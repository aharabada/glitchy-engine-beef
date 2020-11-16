using System;
using ImGui;
using GlitchyEngine.Events;

// Temporary
using GlitchyEngine.Platform.DX11;

namespace GlitchyEngine.ImGui
{
	public class ImGuiLayer : Layer
	{
		public this() : base("ImGuiLayer") {  }

		public override void OnAttach()
		{
			Log.EngineLogger.Trace("Initializing ImGui...");

			ImGui.CHECKVERSION();
			ImGui.CreateContext();
			ImGui.StyleColorsDark();

			ref ImGui.IO io = ref ImGui.GetIO();
			io.ConfigFlags |= .NavEnableKeyboard;
			io.ConfigFlags |= .DockingEnable;
			io.ConfigFlags |= .ViewportsEnable;

			ref ImGui.Style style = ref ImGui.GetStyle();

			if(io.ConfigFlags.HasFlag(.ViewportsEnable))
			{
				style.WindowRounding = 0.0f;
				style.Colors[(int)ImGui.Col.WindowBg].w = 1.0f;
			}

			//ImGui.Dock

#if GE_WINDOWS
			// Todo: temporary, needs to be platform independent
			ImGuiImplDX11.Init(Platform.DX11.DirectX.Device, Platform.DX11.DirectX.ImmediateContext);
			ImGuiImplWin32.Init((Windows.HWnd)(int)Application.Get().Window.NativeWindow);
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
					ref ImGui.IO io = ref ImGui.GetIO();

					switch(e.MouseButton)
					{
					case .LeftButton:
						io.MouseDown[(uint)ImGui.MouseButton.Left] = true;
					case .RightButton:
						io.MouseDown[(uint)ImGui.MouseButton.Right] = true;
					case .MiddleButton:
						io.MouseDown[(uint)ImGui.MouseButton.Middle] = true;
					default:
					}

					return false;
				});

			dispatcher.Dispatch<MouseButtonReleasedEvent>(scope (e) =>
				{
					ref ImGui.IO io = ref ImGui.GetIO();

					switch(e.MouseButton)
					{
					case .LeftButton:
						io.MouseDown[(uint)ImGui.MouseButton.Left] = false;
					case .RightButton:
						io.MouseDown[(uint)ImGui.MouseButton.Right] = false;
					case .MiddleButton:
						io.MouseDown[(uint)ImGui.MouseButton.Middle] = false;
					default:
					}

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
		}

		public void Begin()
		{
			var v = DirectX.ImmediateContext;
			v.OutputMerger.SetRenderTargets(1, &DirectX.BackBufferTarget, null);
			
			ImGuiImplDX11.NewFrame();
			ImGuiImplWin32.NewFrame();
			ImGui.NewFrame();
		}

		bool showDemo = true;
		public void ImGuiRender()
		{
			Begin();

			var event = scope ImGuiRenderEvent();
			Application.Get().OnEvent(event);

			ImGui.ShowDemoWindow(&showDemo);

			End();
		}

		public void End()
		{
			ref ImGui.IO io = ref ImGui.GetIO();

			let window = Application.Get().Window;
			io.DisplaySize = .(window.Width, window.Height);

			ImGui.Render();
			ImGuiImplDX11.RenderDrawData(ref ImGui.GetDrawData());

			if(io.ConfigFlags.HasFlag(.ViewportsEnable))
			{
				ImGui.UpdatePlatformWindows();
				ImGui.RenderPlatformWindowsDefault();
			}
		}
	}
}
