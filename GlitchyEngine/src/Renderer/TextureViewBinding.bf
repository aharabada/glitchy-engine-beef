using System;

namespace GlitchyEngine.Renderer
{
	/// Represents a reference to a texture that can be used as shader input resource.
	public struct TextureViewBinding : IRefCounted, IDisposable
	{
		/// True if the view binding actually has a texture. False otherwise.
		public extern bool IsEmpty { get; }

		public extern void AddRef();
		public extern void Release();

		public void Dispose() => Release();
	}
}
