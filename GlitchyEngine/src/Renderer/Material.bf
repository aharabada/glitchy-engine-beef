using System;
using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer
{
	public class Material : RefCounted
	{
		private Effect _effect ~ _?.ReleaseRef();

		public this(Effect effect)
		{
			_effect = effect..AddRef();
		}

		// public void Set(String name, VALUE)...

		// Float, Float2, Float3, Float4
		// Color, ColorRGB, ColorRGBA
		// Matrix3x3, Matrix4x3, Matrix
		// Int, Int2, Int3, Int4
		// UInt, UInt2, UInt3, UInt4
		// Bool, Bool2, Bool3, Bool4
		// Half, Half2, Half3, Half4
		// Byte, Byte2, Byte3, Byte4

		// Texture
		// Sampler
	}
}
