using System;

namespace GlitchyEngine.Benchmark;

class BenchmarkApp
{
	public static void Main(String[] args)
	{
		BasicBenchmark.BenchmarkSerializer();
	}

	/// Provide a stub implementation for CreateApplication, so that the linker is happy.
	[Export, LinkName("CreateApplication")]
	public static Application CreateApplication(String[] args)
	{
		return null;
	}
}