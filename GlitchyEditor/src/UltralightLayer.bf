using System;
using System.Collections;
using GlitchyEngine;
using GlitchyEngine.System;
using GlitchyEngine.Content;
using GlitchyEngine.Renderer;
using GlitchyEditor.Ultralight;
using Ultralight.CAPI;

namespace GlitchyEditor;

class UltralightLayer : Layer
{
	public static ULRenderer renderer;
	
	public static AssetHandle<Effect> _copyEffect;

	private List<UltralightWindow> _windows = new .() ~ DeleteContainerAndItems!(_);

	public this()
	{
		InitUltralight();

		_windows.Add(new UltralightWindow());

		_copyEffect = Content.LoadAsset("Resources/Shaders/Copy.hlsl");
	}

	private static void InitClipboard()
	{
		ULClipboard clipboard = .();
		clipboard.clear = () => Clipboard.Clear();

		clipboard.read_plain_text = (s) => {
			String text = scope .();
			Clipboard.Read(text);
			ulStringAssignCString(s, text);
		};

		clipboard.write_plain_text = (s) => {
			Clipboard.Set(StringView(ulStringGetData(s)));
		};

		ulPlatformSetClipboard(clipboard);
	}

	private void InitUltralight()
	{
		ULConfig config = ulCreateConfig();

		ulEnablePlatformFontLoader();

		ULString fileSystemPath = ulCreateString(@"D:\Development\Projects\Beef\GlitchyEngine\GlitchyEditor\assets");
		ulEnablePlatformFileSystem(fileSystemPath);
		ulDestroyString(fileSystemPath);

		InitClipboard();

		renderer = ulCreateRenderer(config);
	}

	public override void Update(GameTime gameTime)
	{
		ulUpdate(renderer);

		ulRender(renderer);

		for (var window in _windows)
		{
			window.Render();
		}
	}
}