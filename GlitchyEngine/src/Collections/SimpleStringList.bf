using System;
using System.Collections;

namespace GlitchyEngine.Collections;

struct ListStringView : IHashable
{
	public LessSimpleStringList List;
	public int Index;

	public static explicit operator StringView(ListStringView view)
	{
		return view.List?[view.Index] ?? .();
	}
	
	[Commutable]
	public static bool operator==(ListStringView s1, StringView s2)
	{
		return s2.Equals((StringView)s1);
	}
	
	public int GetHashCode()
	{
		return ((StringView)this).GetHashCode();
	}
}

class LessSimpleStringList
{
	private append String _buffer = .();
	private append List<(int start, int length)> _views = .();

	public StringView this[int index]
	{
		get
		{
			let (start, length) = _views[index];
			return StringView(_buffer, start, length);
		}
	}

	public ListStringView Add(StringView text)
	{
		int lengthBefore = _buffer.Length;

		_buffer.Append(text);
		
		StringView newStringView = StringView(_buffer, lengthBefore);
		_views.Add((lengthBefore, newStringView.Length));
		
		// Append a null terminator to ensure that every string can easily be a C string.
		// Append after creating string view so it isn't part of the view.
		_buffer.Append('\0');

		return .()
			{
				List = this,
				Index = _views.Count - 1
			};
	}

	public delegate void CustomToString(String buffer);

	// Allows adding a string directly into the buffer, using the internal buffer as target for e.g. ToString-opeations.
	public ListStringView Add(CustomToString toString)
	{
		int lengthBefore = _buffer.Length;

		toString(_buffer);

		StringView newStringView = StringView(_buffer, lengthBefore);
		_views.Add((lengthBefore, newStringView.Length));

		// Append a null terminator to ensure that every string can easily be a C string.
		// Append after creating string view so it isn't part of the view.
		_buffer.Append('\0');
		
		return .()
			{
				List = this,
				Index = _views.Count - 1
			};
	}
}


class SimpleStringList
{
	private append String _buffer = .();
	private append List<(int start, int length)> _views = .();

	public StringView this[int index]
	{
		get
		{
			let (start, length) = _views[index];
			return StringView(_buffer, start, length);
		}
	}

	public StringView Add(StringView text)
	{
		int lengthBefore = _buffer.Length;

		_buffer.Append(text);
		
		StringView newStringView = StringView(_buffer, lengthBefore);
		_views.Add((lengthBefore, newStringView.Length));
		
		// Append a null terminator to ensure that every string can easily be a C string.
		// Append after creating string view so it isn't part of the view.
		_buffer.Append('\0');

		return newStringView;
	}

	public delegate void CustomToString(String buffer);

	// Allows adding a string directly into the buffer, using the internal buffer as target for e.g. ToString-opeations.
	public StringView Add(CustomToString toString)
	{
		int lengthBefore = _buffer.Length;

		toString(_buffer);

		StringView newStringView = StringView(_buffer, lengthBefore);
		_views.Add((lengthBefore, newStringView.Length));

		// Append a null terminator to ensure that every string can easily be a C string.
		// Append after creating string view so it isn't part of the view.
		_buffer.Append('\0');

		return newStringView;
	}
}
