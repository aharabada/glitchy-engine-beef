using System;
using static GlitchyEngine.Renderer.Text.FontRenderer;
namespace GlitchyEngine.World.Components;

enum TextRendererFlags
{
	IsRichText = 1,
	NeedsRebuild = 2
}

struct TextRendererComponent : IDisposableComponent, ICopyComponent<TextRendererComponent>
{
	private String _text;
	
	private PreparedText _preparedText;

	private TextRendererFlags _flags;

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

	public PreparedText PreparedText
	{
		get => _preparedText;
		set mut => SetReference!(_preparedText, value);
	}

	public bool IsRichText
	{
		get => _flags.HasFlag(.IsRichText);
		set mut => Enum.SetFlagConditionally(ref _flags, .IsRichText, value);
	}

	public bool NeedsRebuild
	{
		get => _flags.HasFlag(.NeedsRebuild);
		set mut => Enum.SetFlagConditionally(ref _flags, .NeedsRebuild, value);
	}

	public void Dispose()
	{
		delete _text;
		_preparedText?.ReleaseRef();
	}

	public static void Copy(Self* source, Self* target)
	{
		target.Text = source.Text;

		target._flags = source._flags;
		target.NeedsRebuild = true;
	}
}
