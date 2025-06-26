namespace System.Collections;

extension HashSet<T> : ICollection<T> where T : IHashable
{
	public void ICollection<T>.Add(T item)
	{
		Add(item);
	}

	public void CopyTo(Span<T> span)
	{
		int i = 0;
		for (T item in this)
		{
			span[i] = item;
			i++;

			if (i >= span.Length)
				break;
		}
	}
}
