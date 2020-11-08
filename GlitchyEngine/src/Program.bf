using System;
using GlitchLog;
using System.Diagnostics;
using GlitchyEngine.Platform.Windows;

namespace GlitchyEngine
{
	class Program
	{
		[LinkName("CreateApplication")]
		static extern Application CreateApplication();

		public static int Main(String[] args)
		{
			Log.EngineLogger.Info("Initializing Application...");

			Stopwatch initWatch = scope Stopwatch();

			var app = CreateApplication();

			initWatch.Stop();

			Log.EngineLogger.Info("Application initialized ({}ms).", initWatch.ElapsedMilliseconds);
			Log.EngineLogger.Info("Running App...");

			app.Run();
			
			Log.EngineLogger.Info("Uninitializing Application...");

			delete app;

			Log.EngineLogger.Info("Application uninitialized.");

			return 0;
		}
	}
}
