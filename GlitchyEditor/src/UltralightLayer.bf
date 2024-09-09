using System;
using GlitchyEngine;
using Ultralight;
using Ultralight.CAPI;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using GlitchyEngine.Events;
using GlitchyEngine.ImGui;
using ImGui;

namespace GlitchyEditor;

class UltralightLayer : Layer
{
	public this()
	{
		NoApp();
		//RenderApp();
	}

	private static void OnAppUpdate(void* user_data)
	{
		//UltralightLayer layer = (UltralightLayer)Internal.UnsafeCastToObject(user_data);
		//layer.OnAppUpdate();
	}

	private static void OnClose(void* user_data, ULWindow window)
	{
		Log.ClientLogger.Info("OnClose...");
		ulAppQuit(app);
	}

	private static void OnResize(void* user_data, ULWindow window, uint32 width, uint32 height)
	{
		Log.ClientLogger.Info($"OnResize: {width} {height}");
		ulOverlayResize(overlay, width, height);
	}

	///
	/// This callback is bound to a JavaScript function on the page.
	///
	static JSValueRef GetMessage(JSContextRef ctx, JSObjectRef fn, JSObjectRef thisObject, uint32 argumentCount, JSValueRef* arguments, JSValueRef* exception) {
	  ///
	  /// Create a JavaScript String from a C-string, initialize it with our
	  /// welcome message.
	  ///
	  JSStringRef str = JSStringCreateWithUTF8CString("Hello from Beef!");

	  ///
	  /// Create a garbage-collected JSValue using the String we just created.
	  ///
	  ///  **Note**:
	  ///    Both JSValueRef and JSObjectRef types are garbage-collected types. (And actually,
	  ///    JSObjectRef is just a typedef of JSValueRef, they share definitions).
	  ///
	  ///    The garbage collector in JavaScriptCore periodically scans the entire stack to check if
	  ///    there are any active JSValueRefs, and marks those with no references for destruction.
	  ///
	  ///    If you happen to store a JSValueRef/JSObjectRef in heap memory or in memory unreachable
	  ///    by the stack-based garbage-collector, you should explicitly call JSValueProtect() and
	  ///    JSValueUnprotect() on the reference to ensure it is kept alive.
	  ///
	  JSValueRef value = JSValueMakeString(ctx, str);

	  ///
	  /// Release the string we created earlier (we only Release what we Create).
	  ///
	  JSStringRelease(str);

	  return value;
	}

	private static void OnDOMReady(void* user_data, ULView caller, uint64 frame_id, bool is_main_frame, ULString url)
	{
		Log.ClientLogger.Info("OnDOMReady");
		///
		/// Acquire the page's JavaScript execution context.
		///
		/// This locks the JavaScript context so we can modify it safely on this thread, we need to
		/// unlock it when we're done via ulViewUnlockJSContext().
		///
		JSContextRef ctx = ulViewLockJSContext(view);

		///
		/// Create a JavaScript String containing the name of our callback.
		///
		JSStringRef name = JSStringCreateWithUTF8CString("GetMessage");

		///
		/// Create a garbage-collected JavaScript function that is bound to our native C callback 
		/// 'GetMessage()'.
		///
		JSObjectRef func = JSObjectMakeFunctionWithCallback(ctx, name, => GetMessage);

		///
		/// Store our function in the page's global JavaScript object so that it is accessible from the
		/// page as 'GetMessage()'.
		///
		/// The global JavaScript object is also known as 'window' in JS.
		///
		JSObjectSetProperty(ctx, JSContextGetGlobalObject(ctx), name, func, 0, null);

		///
		/// Release the JavaScript String we created earlier.
		///
		JSStringRelease(name);

		///
		/// Unlock the JS context so other threads can modify JavaScript state.
		///
		ulViewUnlockJSContext(view);
	}

	ULRenderer renderer;

	private void NoApp()
	{
		ULConfig config = ulCreateConfig();

		ulEnablePlatformFontLoader();

		ULString fileSystemPath = ulCreateString(@"D:\Development\Projects\Beef\GlitchyEngine\GlitchyEditor\assets");
		ulEnablePlatformFileSystem(fileSystemPath);
		ulDestroyString(fileSystemPath);

		/*ULString styleSheet = ulCreateString("body { background: purple; }");
		ulConfigSetUserStylesheet(config, styleSheet);
		ulDestroyString(styleSheet);*/

		renderer = ulCreateRenderer(config);

		CreateView();
	}

	Texture2D texture ~ _.ReleaseRef();

	private void CopybitmapToTexture(ULBitmap bitmap)
	{
		void* pixels = ulBitmapLockPixels(bitmap);

		uint32 width = ulBitmapGetWidth(bitmap);
		uint32 height = ulBitmapGetHeight(bitmap);
		uint32 stride = ulBitmapGetRowBytes(bitmap);

		Span<Color> colors = Span<Color>((.)pixels, 500 * 500);

		texture.SetData<uint32>((.)pixels, 0, 0, width, height, 0, 0);

		ulBitmapUnlockPixels(bitmap);
	}

	public override void Update(GameTime gameTime)
	{
		ulUpdate(renderer);

		ulRender(renderer);

		ULBitmapSurface surface = ulViewGetSurface(view);

		if (surface != null && !ulIntRectIsEmpty(ulSurfaceGetDirtyBounds(surface)))
		{
			CopybitmapToTexture(ulBitmapSurfaceGetBitmap(surface));
			ulSurfaceClearDirtyBounds(surface);
		}
	}

	private void CreateView()
	{
		ULViewConfig viewConfig = ulCreateViewConfig();
		ulViewConfigSetIsAccelerated(viewConfig, false);
	  
		view = ulCreateView(renderer, 500, 500, viewConfig, null);

		ulDestroyViewConfig(viewConfig);
		
		ULString url = ulCreateString("file:///app.html");
		ulViewLoadURL(view, url);
		ulDestroyString(url);

		//surface = ulViewGetSurface(view);

		// TODO: Dynamic
		Texture2DDesc desc = .(500, 500, .B8G8R8A8_UNorm, usage: .Default, cpuAccess: .Write);

		texture = new Texture2D(desc);
		texture.[Friend]Identifier = .("TestTexture");

		Application.Instance.ContentManager.ManageAsset(texture);
	}

	public override void OnEvent(GlitchyEngine.Events.Event event)
	{
		EventDispatcher dispatcher = EventDispatcher(event);

		dispatcher.Dispatch<ImGuiRenderEvent>(scope (e) => OnImGuiRender(e));

			/*
			dispatcher.Dispatch<WindowResizeEvent>(scope (e) => OnWindowResize(e));
			dispatcher.Dispatch<KeyPressedEvent>(scope (e) => OnKeyPressed(e));
			dispatcher.Dispatch<MouseScrolledEvent>(scope (e) => OnMouseScrolled(e));*/
		
	}

	private bool OnImGuiRender(ImGuiRenderEvent event)
	{
		if (ImGui.Begin("Testlul"))
		{
			ImGui.Image(texture, .(500, 500));

		}
		ImGui.End();

		return false;
	}	
	
	static ULApp app;
	static ULWindow window;
	static ULOverlay overlay;
	static ULView view;

	private void RenderApp()
	{
		///
		/// Create default settings/config
		///
		ULSettings settings = ulCreateSettings();
		ulSettingsSetForceCPURenderer(settings, true);
		ULConfig config = ulCreateConfig();

		ULString fileSystemPath = ulCreateString(@"D:\Development\Projects\Beef\GlitchyEngine\GlitchyEditor\assets");
		ulSettingsSetFileSystemPath(settings, fileSystemPath);
		ulDestroyString(fileSystemPath);
		
		///
		/// Create our App
		///
		app = ulCreateApp(settings, config);
		
		///
		/// Register a callback to handle app update logic.
		///
		ulAppSetUpdateCallback(app, => OnAppUpdate, null);
		
		///
		/// Done using settings/config, make sure to destroy anything we create
		///
		ulDestroySettings(settings);
		ulDestroyConfig(config);
		
		///
		/// Create our window, make it 500x500 with a titlebar and resize handles.
		///
		window = ulCreateWindow(ulAppGetMainMonitor(app), 500, 500, false,
			(uint32)(ULWindowFlags.kWindowFlags_Titled | ULWindowFlags.kWindowFlags_Resizable));

		///
		/// Set our window title.
		///
		ulWindowSetTitle(window, "Ultralight Sample 6 - Intro to C API");
		
		///
		/// Register a callback to handle window close.
		///
		ulWindowSetCloseCallback(window, => OnClose, null);
		
		///
		/// Register a callback to handle window resize.
		///
		ulWindowSetResizeCallback(window, => OnResize, null);
		
		///
		/// Create an overlay same size as our window at 0,0 (top-left) origin. Overlays also create an
		/// HTML view for us to display content in.
		///
		/// **Note**:
		///     Ownership of the view remains with the overlay since we don't explicitly create it.
		///
		overlay = ulCreateOverlay(window, ulWindowGetWidth(window), ulWindowGetHeight(window), 0, 0);
		
		///
		/// Get the overlay's view.
		///
		view = ulOverlayGetView(overlay);
		
		///
		/// Register a callback to handle our view's DOMReady event. We will use this event to setup any
		/// JavaScript <-> C bindings and initialize our page.
		///
		ulViewSetDOMReadyCallback(view, => OnDOMReady, null);

		ulViewSetFailLoadingCallback(view, (user_data, caller, frame_id, is_main_frame, url, description, error_domain, error_code) => {
		   Log.ClientLogger.Error("Errorrr");
		}, null);
		
		///
		/// Load a file from the FileSystem.
		///
		///  **IMPORTANT**: Make sure `file:///` has three (3) forward slashes.
		///
		///  **Note**: You can configure the base path for the FileSystem in the Settings we passed to
		///            ulCreateApp earlier.
		///
		ULString url = ulCreateString("file:///app.html");

		var v = ulStringGetData(url);

		ulViewLoadURL(view, url);
		ulDestroyString(url);
		
		ulAppRun(app);
	}
}