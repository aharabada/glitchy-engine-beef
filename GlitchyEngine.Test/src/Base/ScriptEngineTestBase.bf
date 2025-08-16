using System;
using System.Linq;
using GlitchyEngine.Scripting;
using System.Diagnostics;
using System.IO;
using GlitchyEngine.World;
using System.Collections;

namespace GlitchyEngine.Test.Base;

class ScriptEngineTestBase
{
	public static void Setup()
	{
		Console.WriteLine("Starting up ScriptEngine...");
		Console.WriteLine(Directory.GetCurrentDirectory(.. scope .()));
		ScriptEngine.Init();
		
		ScriptEngine.SetAppAssemblyPath(@"..\GlitchyEngine.Test\content\TestProject\.cache\bin\TestProject.dll");
	}

	protected static void Shutdown()
	{
		Console.WriteLine("Shutting down ScriptEngine...");
		ScriptEngine.Shutdown();
	}
	
	private function void LoadScriptAssemblyFunc(uint8* appData, int64 appLength, uint8* pdbData, int64 pdbLength);
	private function void TestFunc();

	//[Test]
	public static void TestSomeScriptStuff()
	{
		Setup();

		Scene scene = new Scene();
		defer scene.ReleaseRef();

		readonly Entity entity = scene.CreateEntity("Test");
		let script = entity.AddComponent<ScriptComponent>();
		script.ScriptClassName = "TestProject.TestScript";

		Test.Assert(script.Instance == null);

		scene.Start(true, true);

		Test.Assert(script.Instance != null);
		Test.Assert(script.Instance.IsInitialized);
		Test.Assert(!script.Instance.IsCreated);

		scene.Update(scope GameTime(), .Scripts);
		
		Test.Assert(script.Instance.IsCreated);

		scene.Stop();
		
		Test.Assert(script.Instance == null);

		Shutdown();
	}

	//[Test]
	public static void BenchmarkSerializeEmptyScene()
	{
		Setup();

		Scene scene = new Scene();
		defer scene.ReleaseRef();

		ScriptInstanceSerializer serializer = scope .();

		scene.Start(true, true);

		Stopwatch time = scope Stopwatch(startNow: true);

		serializer.SerializeScriptInstances();
		
		time.Stop();

		Console.WriteLine($"Serialized in {time.ElapsedMicroseconds}μs ({time.ElapsedMilliseconds}ms)");

		scene.Stop();
		
		Shutdown();
	}

	static String output = new .() ~ delete _;

	class Benchmark
	{
		public Action BeforeAll;
		public Action BeforeRun;
		public Action Run;
		public Action AfterRun;
		public Action AfterAll;

		private TimeSpan[] _runDurations;

		public void Run(int warmupRuns = 10, int runs = 100)
		{
			BeforeAll?.Invoke();

			Stopwatch watch = scope .();

			watch.Start();
			for (int i < warmupRuns)
			{
				Console.WriteLine($"Warmup run {i + 1}/{warmupRuns}...");
				TimeSpan duration = DoRun();
				Console.WriteLine($"Warmup run {i + 1} finished after {duration.TotalMilliseconds}ms.");
			}
			watch.Stop();
			Console.WriteLine($"Warmup finished after {watch.Elapsed.TotalMilliseconds}ms");

			_runDurations = new TimeSpan[runs];
			defer delete _runDurations;

			for (int i < runs)
			{
				Console.WriteLine($"Starting run {i + 1}/{runs}...");

				watch.Restart();
				_runDurations[i] = DoRun();
				watch.Stop();

				Console.WriteLine($"Run {i + 1}: {_runDurations[i]} (total: {watch.Elapsed.TotalMilliseconds}ms).");
			}

			TimeSpan totalRunTime = _runDurations.Sum();
			TimeSpan meanRunTime = TimeSpan(totalRunTime.Ticks / runs);

			double varianceMs = _runDurations.Select(scope (d) => Math.Pow((d - meanRunTime).TotalMilliseconds, 2)).Sum() / runs;
			TimeSpan stdDeviation = TimeSpan.FromMilliseconds(Math.Sqrt(varianceMs));

			Console.WriteLine($"Results:");
			Console.WriteLine($"Total Time ({runs} runs): {totalRunTime.TotalMilliseconds}ms");
			Console.WriteLine($"Average run Time: {meanRunTime.TotalMilliseconds}ms");
			Console.WriteLine($"Std deviation: {stdDeviation.TotalMilliseconds}ms");

			output.AppendF($"Total: {totalRunTime.TotalMilliseconds}ms | Mean: {meanRunTime.TotalMilliseconds}ms Std: {stdDeviation.TotalMilliseconds}ms\n");

			AfterAll?.Invoke();
		}

		private TimeSpan DoRun()
		{
			Stopwatch watch = scope .();
			BeforeRun?.Invoke();

			watch.Start();
			Run.Invoke();
			watch.Stop();

			AfterRun?.Invoke();

			return watch.Elapsed;
		}
	}

	[Test]
	public static void BenchmarkSerializer()
	{
		// Before benchmark
		Setup();

		Scene scene = new Scene();
		defer scene.ReleaseRef();

		ScriptInstanceSerializer serializer = null;

		let benchmark = scope Benchmark();
		benchmark.BeforeAll = scope [&]() => {
			scene.Start(true, true);
		};
		benchmark.BeforeRun = scope [&]() => {
			serializer = new .();
		};
		benchmark.Run = scope [&]() => {
			serializer.SerializeScriptInstances();
		};
		benchmark.AfterRun = scope [&]() => {
			delete serializer;
		};
		benchmark.AfterAll = scope [&]() => {
			scene.Stop();
		};
		
		Console.WriteLine("Benchmark empty scene:");
		output.AppendF("Benchmark empty scene:");
		{
			benchmark.Run();
		}

		List<Entity> references = new List<Entity>(1000);
		defer delete references;

		void BenchmarkTrivialEntity(int entityCount)
		{
			Console.WriteLine($"Benchmark {entityCount} Trivial Entity:");
			output.AppendF($"Benchmark {entityCount} Trivial Entity:");

			for (int i < entityCount)
			{
				readonly Entity entity = scene.CreateEntity("Test");
				let script = entity.AddComponent<ScriptComponent>();
				script.ScriptClassName = "TestProject.TestScript";

				references.Add(entity);
			}

			benchmark.Run();

			for (Entity e in references)
			{
				scene.DestroyEntity(e);
			}

			references.Clear();
		}

		BenchmarkTrivialEntity(1);
		BenchmarkTrivialEntity(10);
		BenchmarkTrivialEntity(100);
		BenchmarkTrivialEntity(1000);

		void BenchmarkLargeEntity(int entityCount)
		{
			Console.WriteLine($"Benchmark {entityCount} Large Entity:");
			output.AppendF($"Benchmark {entityCount} Large Entity:");

			for (int i < entityCount)
			{
				readonly Entity entity = scene.CreateEntity("Test");
				let script = entity.AddComponent<ScriptComponent>();
				script.ScriptClassName = "TestProject.SerializationTest";
				
				references.Add(entity);
			}

			benchmark.Run();

			for (Entity e in references)
			{
				scene.DestroyEntity(e);
			}

			references.Clear();
		}

		BenchmarkLargeEntity(1);
		BenchmarkLargeEntity(10);
		BenchmarkLargeEntity(100);
		BenchmarkLargeEntity(1000);

		// After Bench
		Shutdown();

		File.WriteAllText("test.log", output);
	}
}