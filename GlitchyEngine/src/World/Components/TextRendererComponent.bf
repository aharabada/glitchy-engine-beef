using System;
namespace GlitchyEngine.World.Components;

struct TextRendererComponent : IDisposableComponent
{
	private String _text;

	private bool _isRichText;

	public StringView Text
	{
		get => _text;
		set mut
		{
			if (_text == null)
				_text = new String();

			_text.Set(value);
		}
	}

	public bool IsRichText
	{
		get => _isRichText;
		set mut => _isRichText = value;
	}

	public void Dispose()
	{
		delete _text;
	}
}
