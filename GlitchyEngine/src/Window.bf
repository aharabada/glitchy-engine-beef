using System;
using GlitchyEngine.Events;
using GlitchyEngine.Math;

namespace GlitchyEngine
{
	public struct WindowDescription
	{
		public uint32 Width;
		public uint32 Height;
		public StringView Title;
		public StringView Icon;

		public this()
		{
			Width = 1280;
			Height = 720;
			Title = "Glitchy Engine";
			Icon = .();
		}

		public this(uint32 width, uint32 height, StringView title, StringView icon = default)
		{
			Width = width;
			Height = height;
			Title = title;
			Icon = icon;
		}
	}

	public abstract class Window
	{
		public delegate void EventCallback(Event e);

		protected EventCallback _eventCallback ~ delete _;

		/**
		 * Gets or Sets the minimum width of the window.
		 */
		public abstract int32 MinWidth {get; set;}
		/**
		 * Gets or Sets the minimum height of the window.
		 */
		public abstract int32 MinHeight {get; set;}
		
		/**
		 * Gets or Sets the maximum width of the window.
		 */
		public abstract int32 MaxWidth {get; set;}
		/**
		 * Gets or Sets the maximum height of the window.
		 */
		public abstract int32 MaxHeight {get; set;}
		
		/**
		 * Gets or Sets the width and height of the window.
		 */
		public abstract Point Size {get; set;}
		/**
		 * Gets or Sets the width of the window.
		 */
		public abstract int32 Width {get; set;}
		/**
		 * Gets or Sets the height of the window.
		 */
		public abstract int32 Height {get; set;}
		
		/**
		 * Gets or Sets the position of the upper-left corner of the client area of the window.
		 */
		public abstract Point Position {get; set;}

		/**
		 * Gets or Sets the x-coordinate of the upper-left corner of the client area of the window.
		 */
		public abstract int32 PositionX {get; set;}
		/**
		 * Gets or Sets the y-coordinate of the upper-left corner of the client area of the window.
		 */
		public abstract int32 PositionY {get; set;}

		/**
		 * Gets or Sets the windows title.
		 */
		public abstract StringView Title {get; set;}

		/**
		 * Gets or Sets whether or not the application uses VSync
		 */
		public abstract bool IsVSync {get; set;}



		public abstract void* NativeWindow {get;}

		public EventCallback EventCallback
		{
			get => _eventCallback;
			set => _eventCallback = value;
		}

		public abstract void Update();

		/**
		 * Function used to create a platform specific window.
		 */
		public static extern Window CreateWindow(WindowDescription description);
	}
}
