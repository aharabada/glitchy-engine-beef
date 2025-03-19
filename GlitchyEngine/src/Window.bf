using System;
using GlitchyEngine.Events;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;

namespace GlitchyEngine
{
	public struct WindowDescription
	{
		public uint32 Width;
		public uint32 Height;
		public StringView Title;
		public StringView Icon;

		public this() => this = default;

		public this(uint32 width, uint32 height, StringView title, StringView icon = default)
		{
			Width = width;
			Height = height;
			Title = title;
			Icon = icon;
		}

		public static readonly WindowDescription Default => .(1280, 720, "Glitchy Engine");
	}

	public class Window
	{
		public delegate void EventCallback(Event e);

		protected EventCallback _eventCallback ~ delete _;
		
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
		 * Gets the windows graphics context.
		 */
		public extern GraphicsContext Context {get;}

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
			set => _eventCallback = value;
		}

		public extern void Update();

		/**
		 * Sets the Icon of the window to the given file.
		 */
		public extern Result<void> SetIcon(StringView filePath);
	}
}
