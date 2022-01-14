using System;
using GlitchLog;
using GlitchyEngine.Debug;
using System.Diagnostics;

namespace GlitchyEngine
{
	class Program
	{
		[LinkName("CreateApplication")]
		static extern Application CreateApplication();

		public static int Main(String[] args)
		{
			Debug.Profiler.BeginProfiling();

			Log.EngineLogger.Info("Initializing Application...");

			Stopwatch initWatch = scope Stopwatch();

			var app = CreateApplication();

			initWatch.Stop();

			Log.EngineLogger.Info($"Application initialized ({initWatch.ElapsedMilliseconds}ms).");
			Log.EngineLogger.Info("Running App...");

			app.Run();
			
			Log.EngineLogger.Info("Uninitializing Application...");

			delete app;

			Log.EngineLogger.Info("Application uninitialized.");

			Debug.Profiler.EndProfiling();

			return 0;
		}
	}
}
