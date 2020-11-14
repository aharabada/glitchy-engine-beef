using System;
using imgui_beef;
using GlitchyEngine.Events;

// Temporary
using DirectX.Windows.VirtualKeyCodes;
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
			io.BackendFlags |= .HasMouseCursors | .HasSetMousePos;

			// Todo: Temporary, needs own keymap
			// Keyboard mapping. ImGui will use those indices to peek into the io.KeysDown[] array that we will update during the application lifetime.
			io.KeyMap[(int32)ImGui.Key.Tab] = VK_TAB;
			io.KeyMap[(int32)ImGui.Key.LeftArrow] = VK_LEFT;
			io.KeyMap[(int32)ImGui.Key.RightArrow] = VK_RIGHT;
			io.KeyMap[(int32)ImGui.Key.UpArrow] = VK_UP;
			io.KeyMap[(int32)ImGui.Key.DownArrow] = VK_DOWN;
			io.KeyMap[(int32)ImGui.Key.PageUp] = VK_PRIOR;
			io.KeyMap[(int32)ImGui.Key.PageDown] = VK_NEXT;
			io.KeyMap[(int32)ImGui.Key.Home] = VK_HOME;
			io.KeyMap[(int32)ImGui.Key.End] = VK_END;
			io.KeyMap[(int32)ImGui.Key.Insert] = VK_INSERT;
			io.KeyMap[(int32)ImGui.Key.Delete] = VK_DELETE;
			io.KeyMap[(int32)ImGui.Key.Backspace] = VK_BACK;
			io.KeyMap[(int32)ImGui.Key.Space] = VK_SPACE;
			io.KeyMap[(int32)ImGui.Key.Enter] = VK_RETURN;
			io.KeyMap[(int32)ImGui.Key.Escape] = VK_ESCAPE;
			io.KeyMap[(int32)ImGui.Key.KeyPadEnter] = VK_RETURN;
			io.KeyMap[(int32)ImGui.Key.A] = (int32)'A';
			io.KeyMap[(int32)ImGui.Key.C] = (int32)'C';
			io.KeyMap[(int32)ImGui.Key.V] = (int32)'V';
			io.KeyMap[(int32)ImGui.Key.X] = (int32)'X';
			io.KeyMap[(int32)ImGui.Key.Y] = (int32)'Y';
			io.KeyMap[(int32)ImGui.Key.Z] = (int32)'Z';
			
			// Todo: temporary, needs to be platform independant
			ImGuiImplDx11.Init(Platform.DX11.DirectX.Device, Platform.DX11.DirectX.ImmediateContext);
		}

		public override void OnDetach()
		{
		}

		public override void OnEvent(Event event)
		{
			EventDispatcher dispatcher = scope EventDispatcher(event);

			dispatcher.Dispatch<WindowResizeEvent>(scope (e) =>
				{
					ref ImGui.IO io = ref ImGui.GetIO();
					io.DisplaySize = .(e.Width, e.Height);
					io.DisplayFramebufferScale = .(1.0f, 1.0f);

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
					
					io.KeyCtrl = io.KeysDown[VK_CONTROL];
					io.KeyShift = io.KeysDown[VK_SHIFT];
					io.KeyAlt = io.KeysDown[VK_MENU];
					io.KeySuper = io.KeysDown[VK_LWIN] || io.KeysDown[VK_RWIN];

					return false;
				});

			dispatcher.Dispatch<KeyReleasedEvent>(scope (e) =>
				{
					ref ImGui.IO io = ref ImGui.GetIO();
					io.KeysDown[(int32)e.KeyCode] = false;
					
					io.KeyCtrl = io.KeysDown[VK_CONTROL];
					io.KeyShift = io.KeysDown[VK_SHIFT];
					io.KeyAlt = io.KeysDown[VK_MENU];
					io.KeySuper = io.KeysDown[VK_LWIN] || io.KeysDown[VK_RWIN];

					return false;
				});

			dispatcher.Dispatch<KeyTypedEvent>(scope (e) =>
				{
					ref ImGui.IO io = ref ImGui.GetIO();
					io.AddInputCharacterUTF16((int16)e.Char);

					return false;
				});
		}

		bool showDemo = true;
		public override void Update(GameTime gameTime)
		{
			var v = DirectX.ImmediateContext;

			v.OutputMerger.SetRenderTargets(1, &DirectX.BackBufferTarget, null);

			ref ImGui.IO io = ref ImGui.GetIO();

			let window = Application.Get().Window;
			io.DisplaySize = .(window.Width, window.Height);
			io.DeltaTime = (float)gameTime.FrameTime.TotalSeconds;

			ImGuiImplDx11.NewFrame();
			ImGui.NewFrame();

			ImGui.ShowDemoWindow(&showDemo);

			ImGui.Render();
			ImGuiImplDx11.RenderDrawData(ImGui.GetDrawData());
		}
	}
}
