using GlitchyEngine.World;
using GlitchyEngine.Scripting;
using System;
using System.Collections;
using System.IO;
using System.Diagnostics;
namespace GlitchyEngine.Benchmark;

class BasicBenchmark
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
	
	/*public static void BenchmarkSerializeEmptyScene()
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
	}*/

	public static void BenchmarkSerializer()
	{
		// Before benchmark
		Setup();

		BenchmarkResult resultCollector = scope .();

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
		{
			benchmark.Name = "Empty Scene";
			benchmark.Run(resultCollector);
		}

		List<Entity> references = new List<Entity>(1000);
		defer delete references;

		void BenchmarkTrivialEntity(int entityCount)
		{
			Console.WriteLine($"Benchmark {entityCount} Trivial Entity:");

			for (int i < entityCount)
			{
				readonly Entity entity = scene.CreateEntity("Test");
				let script = entity.AddComponent<ScriptComponent>();
				script.ScriptClassName = "TestProject.TestScript";

				references.Add(entity);
			}
			
			benchmark.Name = scope $"Trivial Entity {entityCount}";
			benchmark.RunInfo["EntityCount"] = Variant.Create(entityCount);
			benchmark.Run(resultCollector);

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

			for (int i < entityCount)
			{
				readonly Entity entity = scene.CreateEntity("Test");
				let script = entity.AddComponent<ScriptComponent>();
				script.ScriptClassName = "TestProject.SerializationTest";
				
				references.Add(entity);
			}
			
			benchmark.Name = scope $"Large Entity {entityCount}";
			benchmark.RunInfo["EntityCount"] = Variant.Create(entityCount);
			benchmark.Run(resultCollector);

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
		
		String output = scope .();

		List<IResultColumn> columns = scope List<IResultColumn>(BenchmarkResult.DefaultColumns);

		columns.Add(scope IResultColumn() {
			public static String ColumnName => "Per Entity";
			public String Name => ColumnName;

			private static List<StringView> _dependsOn = new List<StringView>(){MeanTimeResultColumn.ColumnName} ~ delete _;
			public Span<StringView> DependsOn => _dependsOn;

			public TimeSpan Calculate(BenchmarkResult.BenchmarkRun runToCalculate, BenchmarkResult allResults)
			{
				if (runToCalculate.RunInfo.TryGetValue("EntityCount", let entityCount))
				{
					TimeSpan meanTime = runToCalculate.ResultColumnValue[MeanTimeResultColumn.ColumnName];

					if (entityCount.TryGet<int>(let count))
					{
						return TimeSpan(meanTime.Ticks / (int)count);
					}
				}

				return default;
			}
		});

		resultCollector.PrintStats(output, customColumns: columns);
		File.WriteAllText("test.log", output);

		Console.WriteLine(output);
	}
}