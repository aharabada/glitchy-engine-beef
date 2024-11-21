using System;
using GlitchyEngine.Core;

namespace GlitchyEngine.Renderer
{
	// TODO: I hate this. It is a reference counting struct?!
	/// Represents a reference to a texture that can be used as shader input resource.
	public class TextureViewBinding : RefCounter
	{
		/// True if the view binding actually has a texture. False otherwise.
		public extern bool IsEmpty { get; }

		public static extern TextureViewBinding CreateDefault();
	}
}
