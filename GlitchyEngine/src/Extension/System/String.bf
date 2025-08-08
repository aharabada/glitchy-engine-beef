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
		
		public void SetF(IFormatProvider formatProvider, StringView format, params Span<Object> args)
		{
			Clear();
			AppendF(formatProvider, format, params args);
		}

		public void SetF(StringView format, params Span<Object> args)
		{
			SetF((IFormatProvider)null, format, params args);
		}

		public int PreviousIndexOf(StringView subStr, int endIdx, bool ignoreCase = false)
		{
			for (int ofs = endIdx - subStr.Length; ofs > 0; ofs--)
			{
				if (Compare(Ptr+ofs, subStr.Length, subStr.Ptr, subStr.Length, ignoreCase) == 0)
					return ofs;
			}

			return -1;
		}
	}
}