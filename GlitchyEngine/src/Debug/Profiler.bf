using System;
using Beefy.utils;

namespace GlitchyEngine.Debug
{
	public static class Profiler
	{
#if !GE_PROFILE
		[SkipCall]
#endif
		public static void BeginProfiling(StringView serverName = "127.0.0.1", StringView sessionName = "GlitchyEngine")
		{
			BeefPerf.Init(serverName, sessionName);
		}
		
#if !GE_PROFILE
		[SkipCall]
#endif
		public static void EndProfiling()
		{
			BeefPerf.Shutdown();
		}
		
#if !GE_PROFILE
		[SkipCall]
#endif
		public static mixin ProfileFunction()
		{
			scope:mixin PerformanceTimer()
		}

#if !GE_PROFILE
		[SkipCall]
#endif
		public static mixin ProfileScope(char8* scopeName)
		{
			scope:mixin PerformanceTimer(scopeName)
		}

		// Extension
		
#if !GE_PROFILE_RENDERER
		[SkipCall]
#endif
		public static mixin ProfileRendererFunction()
		{
			scope:mixin PerformanceTimer()
		}

#if !GE_PROFILE_RENDERER
		[SkipCall]
#endif
		public static mixin ProfileRendererScope(char8* scopeName)
		{
			scope:mixin PerformanceTimer(scopeName)
		}

#if !GE_PROFILE_RESOURCES
		[SkipCall]
#endif
		public static mixin ProfileResourceFunction()
		{
			scope:mixin PerformanceTimer()
		}

#if !GE_PROFILE_RESOURCES
		[SkipCall]
#endif
		public static mixin ProfileResourceScope(char8* scopeName)
		{
			scope:mixin PerformanceTimer(scopeName)
		}
	}

	class PerformanceTimer
	{
		[Inline]
		public this(char8* name = Compiler.CallerMemberName)
		{
#if GE_PROFILE
			[Inline]
			BeefPerf.Enter(name);
#endif
		}
		
		[Inline]
		public ~this()
		{
#if GE_PROFILE
			[Inline]
			BeefPerf.Leave();
#endif
		}
	}
}
