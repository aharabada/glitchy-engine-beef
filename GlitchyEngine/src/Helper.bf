using DirectX.Common;
using GlitchyEngine.Core;
using System.Collections;
using System;

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

		/// Releases the reference to destination, writes newValue into it and adds a reference to newValue.
		public static mixin SetReferenceVar<T>(T destination, T newValue) where T: var
		{
			var oldDest = destination;
			destination = newValue;
			destination?.AddRef();
			oldDest?.Release();
		}

		/// Releases the reference to value and nullifies it.
		public static mixin ReleaseRefAndNullify<T>(T value) where T: RefCounter
		{
			value?.ReleaseRef();
			value = null;
		}
		
		public static mixin DeleteContainerAndReleaseItems(var container)
		{
			if (container != null)
			{
				for (var value in container)
					value?.ReleaseRef();
				delete container;
			}
		}

		public static mixin ClearAndReleaseItems(var container)
		{
			for (var value in container)
				value?.ReleaseRef();
			container.Clear();
		}

		public static mixin DeleteDictionaryAndReleaseValues(var dictionary)
		{
			if (dictionary != null)
			{
				for (var value in dictionary)
				{
					value.value?.ReleaseRef();
				}
				delete dictionary;
			}
		}
		
		public static mixin ClearDictionaryAndDisposeValues(var dictionary)
		{
			if (dictionary != null)
			{
				for (var value in dictionary)
				{
					value.value?.Dispose();
				}
				dictionary.Clear();
			}
		}

		public static mixin DeleteDictionaryAndDisposeValues(var dictionary)
		{
			if (dictionary != null)
			{
				for (var value in dictionary)
				{
					value.value?.Dispose();
				}
				delete dictionary;
			}
		}

		public static mixin ClearDictionaryAndDeleteKeys(var dictionary)
		{
			if (dictionary != null)
			{
				for (var value in dictionary)
					delete value.key;
				dictionary.Clear();
			}
		}

		public static mixin ClearDictionaryAndDeleteValues(var dictionary)
		{
			if (dictionary != null)
			{
				for (var value in dictionary)
					delete value.value;
				dictionary.Clear();
			}
		}

		public static mixin ClearDictionaryAndReleaseKeys(var dictionary)
		{
			if (dictionary != null)
			{
				for (var value in dictionary)
					value.key?.ReleaseRef();
				dictionary.Clear();
			}
		}

		public static mixin ClearDictionaryAndReleaseValues(var dictionary)
		{
			if (dictionary != null)
			{
				for (var value in dictionary)
					value.value?.ReleaseRef();
				dictionary.Clear();
			}
		}
	}
}
