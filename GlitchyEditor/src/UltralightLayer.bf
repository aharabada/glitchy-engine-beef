using System;
using GlitchyEngine;
using Ultralight.CAPI;

namespace GlitchyEditor;

class UltralightLayer : Layer
{
	public const String htmlString =
		"""
		<html>
		  <head>
		    <style type="text/css">
		      body {
		        margin: 0;
		        padding: 0;
		        overflow: hidden;
		        color: black;
		        font-family: Arial;
		        background: linear-gradient(-45deg, #acb4ff, #f5d4e2);
		        display: flex;
		        justify-content: center;
		        align-items: center;
		      }
		      div {
		        width: 350px;
		        height: 350px;
		        text-align: center;
		        border-radius: 25px;
		        background: linear-gradient(-45deg, #e5eaf9, #f9eaf6);
		        box-shadow: 0 7px 18px -6px #8f8ae1;
		      }
		      h1 {
		        padding: 1em;
		      }
		      p {
		        background: white;
		        padding: 2em;
		        margin: 40px;
		        border-radius: 25px;
		      }
		    </style>
		  </head>
		  <body>
		    <div>
		      <h1>Hello World!</h1>
		      <p>Welcome to Ultralight!</p>
		    </div>
		  </body>
		</html>
		""";

	public this()
	{
		RenderToPng();
	}
	
	private static bool done = false;

	private static void OnFinishLoading(void* user_data, ULView caller,
			uint64 frame_id, bool is_main_frame, ULString url)
	{
		///
		/// Our page is done when the main frame is finished loading.
		///
		if (is_main_frame)
		{
			///
			/// Set our done flag to true to exit the Run loop.
			///
			done = true;
		}
	}

	private void RenderToPng()
	{
		///
		/// Setup our config.
		///
		/// @note:
		///   We don't set any config options in this sample but you could set your own options here.
		/// 
		ULConfig config = ulCreateConfig();

		///
		/// We must provide our own Platform API handlers since we're not using ulCreateApp().
		///
		/// The Platform API handlers we can set are:
		///
		/// |                   | ulCreateRenderer() | ulCreateApp() |
		/// |-------------------|--------------------|---------------|
		/// | FileSystem        | **Required**       | *Provided*    |
		/// | FontLoader        | **Required**       | *Provided*    |
		/// | Clipboard         |  *Optional*        | *Provided*    |
		/// | GPUDriver         |  *Optional*        | *Provided*    |
		/// | Logger            |  *Optional*        | *Provided*    |
		/// | SurfaceDefinition |  *Provided*        | *Provided*    |
		///
		/// The only Platform API handlers we are required to provide are file system and font loader.
		///
		/// In this sample we will use AppCore's font loader and file system via
		/// ulEnablePlatformFontLoader() and ulEnablePlatformFileSystem() respectively.
		///
		/// You can replace these with your own implementations later.
		///
		ulEnablePlatformFontLoader();

		///
		/// Use AppCore's file system singleton to load file:/// URLs from the OS.
		///
		ULString base_dir = ulCreateString("./assets/");
		ulEnablePlatformFileSystem(base_dir);
		ulDestroyString(base_dir);

		///
		/// Use AppCore's default logger to write the log file to disk.
		///
		ULString log_path = ulCreateString("./ultralight.log");
		ulEnableDefaultLogger(log_path);
		ulDestroyString(log_path);

		///
		/// Create our renderer using the Config we just set up.
		///
		/// The Renderer singleton maintains the lifetime of the library and is required before creating
		/// any Views. It should outlive any Views.
		/// 
		/// You should set up any platform handlers before creating this.
		///
		ULRenderer renderer = ulCreateRenderer(config);

		ulDestroyConfig(config);

		///
		/// Create our View.
		///
		/// Views are sized containers for loading and displaying web content.
		///
		/// Let's set a 2x DPI scale and disable GPU acceleration so we can render to a bitmap.
		///
		ULViewConfig view_config = ulCreateViewConfig();
		ulViewConfigSetInitialDeviceScale(view_config, 2.0);
		ulViewConfigSetIsAccelerated(view_config, false);

		ULView view = ulCreateView(renderer, 1600, 800, view_config, null);

		ulDestroyViewConfig(view_config);

		///
		/// Register OnFinishLoading() callback with our View.
		///
		ulViewSetFinishLoadingCallback(view, => OnFinishLoading, null);

		///
		/// Load a local HTML file into the View (uses the file system defined above).
		///
		/// @note:
		///   This operation may not complete immediately-- we will call ulUpdate() continuously
		///   and wait for the OnFinishLoading event before rendering our View.
		///
		/// Views can also load remote URLs, try replacing the code below with:
		///
		///   ULString url_string = ulCreateString("https://en.wikipedia.org");
		///   ulViewLoadURL(view, url_string);
		///   ulDestroyString(url_string);
		///
		ULString url_string = ulCreateString("file:///page.html");
		ulViewLoadURL(view, url_string);
		ulDestroyString(url_string);

		Log.ClientLogger.Info("Starting Run(), waiting for page to load...");

		///
		/// Continuously update until OnFinishLoading() is called below (which sets done = true).
		///
		/// @note:
		///   Calling ulUpdate() handles any pending network requests, resource loads, and
		///   JavaScript timers.
		///
		while (!done)
		{
		  ulUpdate(renderer);
		}

		///
		/// Render our View.
		///
		/// @note:
		///   Calling ulRender will render any dirty Views to their respective Surfaces.
		/// 
		ulRender(renderer);

		///
		/// Get our View's rendering surface.
		///
		ULSurface surface = ulViewGetSurface(view);

		///
		/// Get the underlying bitmap.
		///
		/// @note  We're using the default surface definition which is BitmapSurface, you can override
		///        the surface implementation via ulPlatformSetSurfaceDefinition()
		///
		ULBitmap bitmap = ulBitmapSurfaceGetBitmap(surface);
		  
		///
		/// Write our bitmap to a PNG in the current working directory.
		///
		ulBitmapWritePNG(bitmap, "result.png");
		  
		Log.ClientLogger.Info("Saved a render of our page to result.png.");
	}
}