using DirectX.Common;
using GlitchyEngine.Core;

namespace GlitchyEngine
{
	static
	{
		/// Releases the reference to destination, writes newValue into it and adds a reference to newValue.
		public static mixin SetReference<T>(T destination, T newValue) where T: RefCounter
		{
			var oldDest = destination;
			destination = newValue;
			destination?.AddRef();
			oldDest?.ReleaseRef();
		}

		/// Releases the reference to value and nullifies it.
		public static mixin ReleaseRefAndNullify<T>(T value) where T: RefCounter
		{
			value?.ReleaseRef();
			value = null;
		}
	}
}
