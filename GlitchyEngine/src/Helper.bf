using System;
using DirectX.Common;

namespace GlitchyEngine
{
	static
	{
		/// Releases the reference to destination, writes newValue into it and adds a reference to newValue.
		public static mixin SetReference<T>(T destination, T newValue) where T: RefCounted
		{
			destination?.ReleaseRef();
			destination = newValue;
			destination?.AddRef();
		}

		/// Releases the reference to value and nullifies it.
		public static mixin ReleaseRefAndNullify<T>(T value) where T: RefCounted
		{
			value?.ReleaseRef();
			value = null;
		}
	}
}
