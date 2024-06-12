using System;
using GlitchyEditor.EditWindows;
using GlitchyEngine.Content;
using ImGui;

namespace GlitchyEditor.Assets;

class SpriteEditor : ClosableWindow
{
	AssetHandle _assetHandle;

	public this(Editor editor, AssetHandle assetHandle) : base(editor, "Sprite Editor")
	{
		_assetHandle = assetHandle;
	}

	protected override void InternalShow()
	{
		ImGui.Text("Nothing to see here, yet...");
	}
}