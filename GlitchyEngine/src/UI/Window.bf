using System;
using GlitchyEngine.Events;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;

namespace GlitchyEngine.UI
{
	enum WindowStyle
	{
		Normal,
		Borderless,
		CustomTitle
	}

	public struct WindowDescription
	{
		public uint32 Width;
		public uint32 Height;
		public StringView Title;
		public StringView Icon;
		public WindowStyle WindowStyle;

		public this() => this = default;

		public this(uint32 width, uint32 height, StringView title, StringView icon = default, WindowStyle windowStyle = .Normal)
		{
			Width = width;
			Height = height;
			Title = title;
			Icon = icon;
			WindowStyle = windowStyle;
		}

		public static readonly WindowDescription Default => .(1280, 720, "Glitchy Engine")
	}

	public class Window
	{
		private SwapChain _swapChain ~ delete _;

		public delegate void EventCallback(Event e);

		protected EventCallback _eventCallback = new => DefaultEventHandler ~ delete _;

		public SwapChain SwapChain => _swapChain;

		public extern this(WindowDescription windowDescription);

		/**
		 * Gets or Sets the minimum width of the window.
		 */
		public extern int32 MinWidth {get; set;}
		/**
		 * Gets or Sets the minimum height of the window.
		 */
		public extern int32 MinHeight {get; set;}
		
		/**
		 * Gets or Sets the maximum width of the window.
		 */
		public extern int32 MaxWidth {get; set;}
		/**
		 * Gets or Sets the maximum height of the window.
		 */
		public extern int32 MaxHeight {get; set;}
		
		/**
		 * Gets or Sets the width and height of the window.
		 */
		public extern int2 Size {get; set;}
		/**
		 * Gets or Sets the width of the window.
		 */
		public extern int32 Width {get; set;}
		/**
		 * Gets or Sets the height of the window.
		 */
		public extern int32 Height {get; set;}
		
		/**
		 * Gets or Sets the position of the upper-left corner of the client area of the window.
		 */
		public extern int2 Position {get; set;}

		/**
		 * Gets or Sets the x-coordinate of the upper-left corner of the client area of the window.
		 */
		public extern int32 PositionX {get; set;}
		/**
		 * Gets or Sets the y-coordinate of the upper-left corner of the client area of the window.
		 */
		public extern int32 PositionY {get; set;}

		/**
		 * Gets or Sets the windows title.
		 */
		public extern StringView Title {get; set;}

		/**
		 * Gets or Sets whether or not the application uses VSync
		 */
		public extern bool IsVSync {get; set;}

		/**
		 * Gets a pointer to the platform specific window representation.
		 */
		public extern void* NativeWindow {get;}

		/**
		 * Gets whether or not the window is active.
		 */
		public extern bool IsActive {get;}

		public EventCallback EventCallback
		{
			get => _eventCallback;
			set
			{
				delete _eventCallback;
				_eventCallback = value;
			}
		}

		public extern void Update();

		/**
		 * Sets the Icon of the window to the given file.
		 */
		public extern Result<void> SetIcon(StringView filePath);

		public extern Result<void> SetCursor(CursorImage cursorImage);

		private void DefaultEventHandler(Event e)
		{
			Log.EngineLogger.Error($"No event handler registered for window.");
		}
	}
}
