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
	
	private List<UltralightWindow> _windows = new .() ~ DeleteContainerAndItems!(_);

	public UltralightMainWindow EntityHierarchyWindow;

	private static Self _instance;

	public static Self Instance => _instance;

	public this()
	{
		_instance = this;

		InitUltralight();

		EntityHierarchyWindow = new UltralightMainWindow();
		_windows.Add(EntityHierarchyWindow);
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

		//ulConfigSetUserStylesheet(config);

		/*ULString logPath = ulCreateString(@"D:\Development\Projects\Beef\GlitchyEngine\GlitchyEditor\ul.log");
		ulEnableDefaultLogger(logPath);
		ulDestroyString(logPath);*/

		ulEnablePlatformFontLoader();

		ULString fileSystemPath = ulCreateString("./EditorUI/dist");
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