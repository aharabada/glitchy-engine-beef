using System;
using System.Diagnostics;
using System.Linq;
using System.Collections;
using System.Collections;

namespace GlitchyEngine.Benchmark;

class BenchmarkResult
{
	public class BenchmarkRun
	{
		public String Name  { get; private set; } ~ delete:append _;
		public TimeSpan[] RunDurations  { get; private set; } ~ delete:append _;
		
		public int RunCount => RunDurations.Count;

		public TimeSpan TotalRunTime { get; private set; }
		public TimeSpan MeanRunTime { get; private set; }
		public TimeSpan RuntimeStdDev { get; private set; }

		[AllowAppend]
		public this(StringView name, int runCount)
		{
			String appendedName = append String(name);
			TimeSpan[] appendedRunDurations = append TimeSpan[runCount];

			Name = appendedName;
			RunDurations = appendedRunDurations;
		}

		public void CalculateStats()
		{
			TotalRunTime = RunDurations.Sum();
			MeanRunTime = TimeSpan(TotalRunTime.Ticks / RunCount);

			int64 variance = RunDurations.Select(scope (d) => {
					TimeSpan delta = d - MeanRunTime;
					return (delta * delta).Ticks / RunCount;
				}).Sum();
			RuntimeStdDev = TimeSpan((int64)Math.Sqrt((double)variance));
		}
	}

	private append List<BenchmarkRun> _runData ~ ClearAndDeleteItems!(_);

	public this()
	{
	}

	public BenchmarkRun NewRun(StringView name, int iterations)
	{
		BenchmarkRun newRunResult = new BenchmarkRun(name, iterations);
		_runData.Add(newRunResult);

		return newRunResult;
	}

	private enum TimeUnit
	{
		Milliseconds,
		Seconds,
		Minutes,
		Hours,
		Days
	}

	private TimeUnit FigureOutUnits<T>(T timeData) where T : concrete, IEnumerable<TimeSpan>
	{
		TimeSpan shortestMeanTime = _runData.Select(scope (s) => s.MeanRunTime).Min();

		if (shortestMeanTime.TotalDays > 2)
		{
			return .Days;
		}
		else if (shortestMeanTime.TotalHours > 2)
		{
			return .Hours;
		}
		else if (shortestMeanTime.TotalMinutes > 5)
		{
			return .Minutes;
		}
		else if (shortestMeanTime.TotalSeconds > 10)
		{
			return .Seconds;
		}
		else
		{
			return .Milliseconds;
		}
	}

	private void PrintTimeSpan(TimeSpan timeToPrint, TimeUnit unitToPrint, String outBuffer)
	{
		switch (unitToPrint)
		{
		case .Milliseconds:
			outBuffer.AppendF($"{timeToPrint.TotalMilliseconds:f3} ms");
		case .Seconds:
			outBuffer.AppendF($"{timeToPrint.TotalSeconds:f3} s");
		case .Minutes:
			outBuffer.AppendF($"{timeToPrint.TotalMinutes:f3} m");
		case .Hours:
			outBuffer.AppendF($"{timeToPrint.TotalHours:f3} h");
		case .Days:
			outBuffer.AppendF($"{timeToPrint.TotalDays:f3} d");
		}
	}

	public void PrintStats(String outString, bool printHeader = true, TimeUnit? forcedTimeUnit = null)
	{
		for (BenchmarkRun run in _runData)
		{
			run.CalculateStats();
		}

		TimeUnit printedUnit = forcedTimeUnit ?? FigureOutUnits(_runData.Select(scope (s) => s.MeanRunTime));

		var widths = (NameColumn: 8, TotalTimeColumn: 7, MeanTimeColumn: 7, StdDevColumn: 7);

		SimpleStringList preparedStrings = scope .();
		for (BenchmarkRun run in _runData)
		{
			// Print Name
			widths.NameColumn = Math.Max(widths.NameColumn, run.Name.Length);

			// Print Total Time
			StringView totalRunTimeView = preparedStrings.Add(scope (s) => PrintTimeSpan(run.TotalRunTime, printedUnit, s));
			widths.TotalTimeColumn = Math.Max(widths.TotalTimeColumn, totalRunTimeView.Length);

			// Print Total Time
			StringView meanRunTimeView = preparedStrings.Add(scope (s) => PrintTimeSpan(run.MeanRunTime, printedUnit, s));
			widths.MeanTimeColumn = Math.Max(widths.MeanTimeColumn, meanRunTimeView.Length);

			// Print Standard Deviation
			StringView stdDevView = preparedStrings.Add(scope (s) => PrintTimeSpan(run.RuntimeStdDev, printedUnit, s));
			widths.StdDevColumn = Math.Max(widths.StdDevColumn, stdDevView.Length);
		}

		String lineFormat = scope $"| {{, -{widths.NameColumn}}} | {{, {widths.TotalTimeColumn}}} | {{, {widths.MeanTimeColumn}}} | {{, {widths.StdDevColumn}}} |\n";

		if (printHeader)
		{
			int lengthBefore = outString.Length;
			outString.AppendF(lineFormat, Formatter.Center("Benchmark", widths.NameColumn), Formatter.Center("Total", widths.TotalTimeColumn),
				Formatter.Center("Mean", widths.MeanTimeColumn), Formatter.Center("Std", widths.StdDevColumn));
			int lineLength = outString.Length - lengthBefore;
			outString.Append('-', lineLength - 1);
			outString.Append('\n');
		}
		
		int preparedStringIndex = 0;
		for (BenchmarkRun run in _runData)
		{
			outString.AppendF(lineFormat, run.Name, preparedStrings[preparedStringIndex++], preparedStrings[preparedStringIndex++], preparedStrings[preparedStringIndex++]);
		}
	}
}

class Benchmark
{
	private append String _name = .();

	public StringView Name
	{
		get => _name;
		set => _name.Set(value);
	}

	public Action BeforeAll;
	public Action BeforeRun;
	public Action Run;
	public Action AfterRun;
	public Action AfterAll;

	public void Run(BenchmarkResult resultsCollector, int warmupRuns = 10, int runs = 100)
	{
		let resultData = resultsCollector.NewRun(Name, runs);

		BeforeAll?.Invoke();

		Stopwatch watch = scope .();

		watch.Start();
		for (int i < warmupRuns)
		{
			Console.Write($"Warmup run {i + 1}/{warmupRuns}...");
			Console.CursorLeft = 0;
			//TimeSpan duration = DoRun();
			//Console.WriteLine($"Warmup run {i + 1} finished after {duration.TotalMilliseconds}ms.");
		}
		watch.Stop();
		Console.WriteLine($"Warmup finished after {watch.Elapsed.TotalMilliseconds}ms");

		for (int i < runs)
		{
			Console.Write($"Starting run {i + 1}/{runs}...");
			Console.CursorLeft = 0;

			watch.Restart();
			resultData.RunDurations[i] = DoRun();
			watch.Stop();

			//Console.WriteLine($"Run {i + 1}: {_runDurations[i]} (total: {watch.Elapsed.TotalMilliseconds}ms).");
		}

		resultData.CalculateStats();

		Console.WriteLine(scope $"Finished: Total ({runs} runs) {resultData.TotalRunTime.TotalMilliseconds}ms | Mean: {resultData.MeanRunTime.TotalMilliseconds}ms | Std Dev: {resultData.RuntimeStdDev.TotalMilliseconds}ms");

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
