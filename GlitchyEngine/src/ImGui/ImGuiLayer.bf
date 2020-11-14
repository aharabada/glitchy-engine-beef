using System;
using imgui_beef;
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
			io.BackendFlags |= .HasMouseCursors | .HasSetMousePos;

			// Todo: Temporary, needs own keymap
			// Keyboard mapping. ImGui will use those indices to peek into the io.KeysDown[] array that we will update during the application lifetime.
			io.KeyMap[(int32)ImGui.Key.Tab] = (int32)Key.Tab;
			io.KeyMap[(int32)ImGui.Key.LeftArrow] = (int32)Key.Left;
			io.KeyMap[(int32)ImGui.Key.RightArrow] = (int32)Key.Right;
			io.KeyMap[(int32)ImGui.Key.UpArrow] = (int32)Key.Up;
			io.KeyMap[(int32)ImGui.Key.DownArrow] = (int32)Key.Down;
			io.KeyMap[(int32)ImGui.Key.PageUp] = (int32)Key.Prior;
			io.KeyMap[(int32)ImGui.Key.PageDown] = (int32)Key.Next;
			io.KeyMap[(int32)ImGui.Key.Home] = (int32)Key.Home;
			io.KeyMap[(int32)ImGui.Key.End] = (int32)Key.End;
			io.KeyMap[(int32)ImGui.Key.Insert] = (int32)Key.Insert;
			io.KeyMap[(int32)ImGui.Key.Delete] = (int32)Key.Delete;
			io.KeyMap[(int32)ImGui.Key.Backspace] = (int32)Key.Backspace;
			io.KeyMap[(int32)ImGui.Key.Space] = (int32)Key.Space;
			io.KeyMap[(int32)ImGui.Key.Enter] = (int32)Key.Return;
			io.KeyMap[(int32)ImGui.Key.Escape] = (int32)Key.Escape;
			io.KeyMap[(int32)ImGui.Key.KeyPadEnter] = (int32)Key.Return;
			io.KeyMap[(int32)ImGui.Key.A] = (int32)(int32)Key.A;
			io.KeyMap[(int32)ImGui.Key.C] = (int32)(int32)Key.C;
			io.KeyMap[(int32)ImGui.Key.V] = (int32)(int32)Key.V;
			io.KeyMap[(int32)ImGui.Key.X] = (int32)(int32)Key.X;
			io.KeyMap[(int32)ImGui.Key.Y] = (int32)(int32)Key.Y;
			io.KeyMap[(int32)ImGui.Key.Z] = (int32)(int32)Key.Z;
			
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
