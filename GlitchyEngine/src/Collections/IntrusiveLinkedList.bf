using System;
using System.Collections;

namespace GlitchyEngine.Collections;

/*class IntrusiveLinkedList<T> : ICollection<T> where T : ILinkedListElement, var
{
	private T _head;
	private T _tail;

	private bool _ownsElements;

	public void Add(T element)
	{
		element.List = this;
		if (_head == null)
		{
			_head = _tail = element;
		}
		else
		{
			//_tail.ListLink.Previous = this;
		}
	}

	public void Clear()
	{

	}

	public bool Contains(T item)
	{
		return default;
	}

	public void CopyTo(Span<T> span)
	{

	}

	public bool Remove(T item)
	{
		return default;
	}
}

class ListLink<T> where T : ILinkedListElement
{
	public IntrusiveLinkedList<T> List { get; internal set; }
	public ListLink<T> Previous { get; internal set; }
	public ListLink<T> Next { get; internal set; }
}

interface ILinkedListElement
{
}

[AttributeUsage(.Class | .Struct)]
struct IntrusiveLinkedListAttribute : Attribute, IComptimeTypeApply
{
	[Comptime]
	public void ApplyToType(Type type)
	{
		Compiler.EmitAddInterface(type, typeof(ILinkedListElement));

		Compiler.EmitTypeBody(type, new $"""
			//ListLink<{type}> _listLink;
			public using ListLink<{type}> _listLink;
			public ListLink<{type}> ListLink => _listLink;
			""");
	}
}

[IntrusiveLinkedList]
class LLTest
{
}*/