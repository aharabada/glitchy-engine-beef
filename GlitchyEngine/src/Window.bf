using System;
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

	// Todo: interface?
	public abstract class Window
	{
		// Todo: callback/events?

		/**
		 * Gets or Sets the width of the window.
		 */
		public abstract int32 Width {get; set;}
		/**
		 * Gets or Sets the height of the window.
		 */
		public abstract int32 Height {get; set;}
		/**
		 * Gets or Sets the windows title.
		 */
		public abstract StringView Title {get; set;}

		/**
		 * Gets or Sets whether or not the application uses VSync
		 */
		public abstract bool IsVSync {get; set;}

		public abstract void Update();
	}
}
