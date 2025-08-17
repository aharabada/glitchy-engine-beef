using System;
using System.Diagnostics;
using System.Linq;
using System.Collections;
using System.Collections;
using GlitchyEngine.Collections;

using static GlitchyEngine.Benchmark.BenchmarkResult;

namespace GlitchyEngine.Benchmark;

public interface IResultColumn
{
	String Name => ColumnName;
	static String ColumnName { get; }

	Span<StringView> DependsOn => null;
	TimeSpan Calculate(BenchmarkRun runToCalculate, BenchmarkResult allResults);
}

class TotalTimeResultColumn : IResultColumn
{
	public static String ColumnName => "Total";
	public String Name => ColumnName;

	public TimeSpan Calculate(BenchmarkResult.BenchmarkRun runToCalculate, BenchmarkResult allRuns)
	{
		return runToCalculate.RunDurations.Sum();
	}
}

class MeanTimeResultColumn : IResultColumn
{
	public static String ColumnName => "Mean";
	public String Name => ColumnName;

	private static List<StringView> _dependsOn = new List<StringView>(){TotalTimeResultColumn.ColumnName} ~ delete _;
	public Span<StringView> DependsOn => _dependsOn;

	public TimeSpan Calculate(BenchmarkResult.BenchmarkRun runToCalculate, BenchmarkResult allRuns)
	{
		return TimeSpan(runToCalculate.ResultColumnValue[TotalTimeResultColumn.ColumnName].Ticks / runToCalculate.RunCount);
	}
}

class StdDevResultColumn : IResultColumn
{
	public static String ColumnName => "Std";
	public String Name => ColumnName;
	
	private static List<StringView> _dependsOn = new List<StringView>(){MeanTimeResultColumn.ColumnName} ~ delete _;
	public Span<StringView> DependsOn => _dependsOn;

	public TimeSpan Calculate(BenchmarkResult.BenchmarkRun runToCalculate, BenchmarkResult allRuns)
	{
		TimeSpan meanTime = runToCalculate.ResultColumnValue[MeanTimeResultColumn.ColumnName];

		int64 variance = runToCalculate.RunDurations.Select(scope (d) => {
				TimeSpan delta = d - meanTime;
				return (delta * delta).Ticks / runToCalculate.RunCount;
			}).Sum();
		return TimeSpan((int64)Math.Sqrt((double)variance));
	}
}

class BenchmarkResult
{
	public class BenchmarkRun
	{
		public String Name  { get; private set; } ~ delete:append _;
		public TimeSpan[] RunDurations  { get; private set; } ~ delete:append _;
		
		public int RunCount => RunDurations.Count;

		public append Dictionary<StringView, TimeSpan> ResultColumnValue = .();
		public append Dictionary<StringView, Variant> RunInfo = .() ~ {
			for (var v in _.Values)
			{
				v.Dispose();
			}
		};

		[AllowAppend]
		public this(StringView name, int runCount)
		{
			String appendedName = append String(name);
			TimeSpan[] appendedRunDurations = append TimeSpan[runCount];
			
			Name = appendedName;
			RunDurations = appendedRunDurations;
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
		/*TimeSpan shortestMeanTime = _runData.Select(scope (s) => s.MeanRunTime).Min();

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
		else*/
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
	
	typealias DagColumnNode = TreeNode<IResultColumn>;
	typealias ColDepth = (IResultColumn Column, int Depth);

	private void BuildDag(Span<IResultColumn> customColumns, List<IResultColumn> outColumnCalculationPlan)
	{
		Dictionary<StringView, ColDepth> nameToColumns = scope .();

		for (IResultColumn column in customColumns)
		{
			nameToColumns.TryAdd(column.Name, (column, -1));
		}

		for (ref ColDepth entry in ref nameToColumns.Values)
		{
			int CalculateDepth(ColDepth columnWithDepth)
			{
				if (columnWithDepth.Depth != -1)
					return columnWithDepth.Depth;

				if (columnWithDepth.Column.DependsOn.IsEmpty)
				{
					return 0;
				}

				int maxParentDepth = -1;

				for (StringView parentName in columnWithDepth.Column.DependsOn)
				{
					if (nameToColumns.TryGetRef(parentName, let _, let parentEntry))
					{
						int currentParentsDepth = CalculateDepth(*parentEntry);
						parentEntry.Depth = currentParentsDepth;

						maxParentDepth = Math.Max(maxParentDepth, currentParentsDepth);
					}
				}

				return maxParentDepth + 1;
			}

			entry.Depth = CalculateDepth(entry);
		}

		List<ColDepth> columnsToSort = new List<ColDepth>(nameToColumns.Values);
		defer delete columnsToSort;
		columnsToSort.Sort(scope (a, b) => a.Depth <=> b.Depth);

		outColumnCalculationPlan.AddRange(columnsToSort.Select(scope (a) => a.Column));
	}

	private void CalculateStats(Span<IResultColumn> customColumns)
	{
		List<IResultColumn> orderedColumns = scope List<IResultColumn>();

		BuildDag(customColumns, orderedColumns);

		for (IResultColumn columnToCalculate in orderedColumns)
		{
			for (BenchmarkRun runToCalculate in _runData)
			{
				runToCalculate.ResultColumnValue[columnToCalculate.Name] = columnToCalculate.Calculate(runToCalculate, this);
			}
		}
	}

	public static List<IResultColumn> DefaultColumns = new List<IResultColumn>(){
		new TotalTimeResultColumn(), new MeanTimeResultColumn(), new StdDevResultColumn()} ~ DeleteContainerAndItems!(_);

	public void PrintStats(String outString, bool printHeader = true, TimeUnit forcedTimeUnit = .Milliseconds, Span<IResultColumn> customColumns = null)
	{
		var customColumns;
		if (customColumns.IsEmpty)
			customColumns = DefaultColumns;

		CalculateStats(customColumns);

		//TODO: TimeUnit printedUnit = forcedTimeUnit ?? FigureOutUnits(_runData.Select(scope (s) => s.MeanRunTime));
		TimeUnit printedUnit = forcedTimeUnit;

		int nameColumnWidth = 0;
		int[] columnWidths = scope int[customColumns.Length];

		// Prints all numbers into a buffer, calculates column widths
		SimpleStringList preparedStrings = scope .();
		for (BenchmarkRun run in _runData)
		{
			nameColumnWidth = Math.Max(nameColumnWidth, run.Name.Length);

			for (IResultColumn column in customColumns)
			{
				StringView printedValue = preparedStrings.Add(scope (s) => PrintTimeSpan(run.ResultColumnValue[column.Name], printedUnit, s));
				columnWidths[@column.Index] = Math.Max(columnWidths[@column.Index], printedValue.Length);
			}
		}

		if (printHeader)
		{
			nameColumnWidth = Math.Max(nameColumnWidth, "Benchmark".Length);

			int lengthBefore = outString.Length;

			outString.Append("|");
			outString.AppendF($" {Formatter.Center("Benchmark", nameColumnWidth)} |");

			for (IResultColumn column in customColumns)
			{
				columnWidths[@column.Index] = Math.Max(columnWidths[@column.Index], column.Name.Length);
				
				outString.AppendF($" {Formatter.Center(column.Name, columnWidths[@column.Index])} |");
			}

			outString.Append('\n');

			// Print dashed line to separate header
			int lineLength = outString.Length - lengthBefore;
			outString.Append('-', lineLength - 1);
			outString.Append('\n');
		}

		int preparedStringIndex = 0;


		for (BenchmarkRun run in _runData)
		{
			outString.Append("|");
			outString.AppendF($" {Formatter.LeftAlign(run.Name, nameColumnWidth)} |");

			for (int i < customColumns.Length)
			{
				outString.AppendF($" {Formatter.RightAlign(preparedStrings[preparedStringIndex++], columnWidths[i])} |");
			}

			outString.Append('\n');
		}
	}
}

class Benchmark
{
	private append String _name = .();
	
	public append Dictionary<StringView, Variant> RunInfo = .();

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
		for (var kv in RunInfo)
			resultData.RunInfo[kv.key] = kv.value;

		BeforeAll?.Invoke();

		Stopwatch watch = scope .();

		watch.Start();
		for (int i < warmupRuns)
		{
			Console.Write($"Warmup run {i + 1}/{warmupRuns}...");
			Console.CursorLeft = 0;
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
		}

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
