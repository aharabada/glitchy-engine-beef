namespace System
{
	extension String
	{
		[Inline]
		public void CopyTo(Span<char8> target)
		{
			CopyTo(target.Ptr, target.Length);
		}
		
		[Inline]
		public void CopyTo(char8* target, int targetLength)
		{
			int copiedChars = Math.Min(targetLength - 1, Length);

			Internal.MemCpy(target, Ptr, copiedChars);

			target[copiedChars] = '\0';
		}

		/// Converts camel case and delimiter-separated words to normal words.
		public void ToHumanReadable()
		{
			// TODO!
		}
	}
}