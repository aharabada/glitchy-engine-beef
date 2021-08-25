namespace System
{
	public extension Array1<T>
	{
		/// Returns the index of the given element or -1 if it is not in this array.
		public int IndexOf(T element)
		{
			for(int i < mLength)
				if(Ptr[i] == element)
					return i;

			return -1;
		}

		/**
		 * Uses Binary Search to find the index of the given Element.
		 * @param element The element whose element will be returned.
		 * @returns The index of the element in the array or -1 if it is not in the array.
		 * @Note this function only works if the entries of the array are sorted in ascending order.
		 */
		public int IndexOfBinary(T element) where bool : operator T < T
		{
			int lowerBound = 0;
			int upperBound = mLength;

			while(lowerBound != upperBound)
			{
				int index = (lowerBound + upperBound) / 2;

				T elementAtIndex = Ptr[index];

				if(elementAtIndex == element)
				{
					return index;
				}
				else if(elementAtIndex < element)
				{
					upperBound = index;
				}
				else
				{
					lowerBound = index;
				}
			}

			return -1;
		}
	}
}
