namespace System.Collections;

extension List<T>
{
	public bool Equals(List<T> other)
	{
		if (this === other)
			return true;

		if (this.Count != other.Count)
			return false;

		for (int i < this.Count)
		{
			if (this[i] != other[i])
				return false;
		}

		return true;
	}
}
