#if BF_PLATFORM_WINDOWS

using System;
using System.Diagnostics;
using System.Threading;
using DirectX.Common;
using GlitchyEngine;
using GlitchyEditor.Platform.Windows.Com;

namespace GlitchyEditor.CodeEditors;

/// A request to open the script solution (or a file in it) in Visual Studio.
/// Runs on its own worker thread so the editor never blocks on a busy or starting Visual Studio.
class DteOpenRequest
{
	private const int ColdStartMaxPolls = 120;
	private const int ColdStartPollIntervalMs = 500;

	private append String _solutionPath = .();
	private append String _devenvPath = .();
	private append String _fileName = .();

	public StringView SolutionPath
	{
		get => _solutionPath;
		set => _solutionPath.Set(value);
	}
	
	public StringView DevenvPath
	{
		get => _devenvPath;
		set => _devenvPath.Set(value);
	}
	
	/// Leave empty to just open the project.
	public StringView FileName
	{
		get => _fileName;
		set => _fileName.Set(value);
	}

	public int LineNumber;

	private static int32 sWorkerActive = 0;

	public static void Start(DteOpenRequest ownRequest)
	{
		if (Interlocked.CompareExchange(ref sWorkerActive, 0, 1) != 0)
		{
			Log.EngineLogger.Info("Visual Studio is already being opened, ignoring the request.");
			delete ownRequest;
			return;
		}

		Thread workerThread = new Thread(new () =>
		{
			ownRequest.Run();
			delete ownRequest;

			Interlocked.Exchange(ref sWorkerActive, 0);
		});
		workerThread.SetName("Visual Studio DTE worker");
		// Don't block editor shutdown on a worker that is still polling; skipping the COM cleanup
		// at process exit is harmless.
		workerThread.IsBackground = true;
		workerThread.Start(true);
	}

	private void Run()
	{
		// The worker does its own COM initialization, the editor main thread (STA via OleInitialize)
		// stays untouched.
		if (CoInitializeEx(null, COINIT_APARTMENTTHREADED).Failed(let result))
		{
			Log.EngineLogger.Error(scope $"CoInitializeEx failed: {result} ({(uint32)result:X8})");
			return;
		}

		defer CoUninitialize();

		if (VisualStudioDte.FindRunningInstance(SolutionPath) case .Ok(let dte))
		{
			if (FileName.IsEmpty)
				VisualStudioDte.ActivateMainWindow(dte);
			else
				VisualStudioDte.OpenFileAtLine(dte, FileName, LineNumber).IgnoreError();

			delete dte;

			return;
		}

		Log.EngineLogger.Info(scope $"No running Visual Studio instance has \"{SolutionPath}\" open, starting a new one.");

		ProcessStartInfo startInfo = scope .();
		startInfo.SetFileName(DevenvPath);
		startInfo.SetArguments(scope $"\"{SolutionPath}\"");

		if (scope SpawnedProcess().Start(startInfo) case .Err)
		{
			Log.EngineLogger.Error(scope $"Failed to start Visual Studio (\"{DevenvPath}\").");
			return;
		}

		if (FileName.IsEmpty)
			return;

		// Wait for the new instance to finish loading the solution (Solution.FullName stays empty
		// until then), then open the file in it.
		for (int i < ColdStartMaxPolls)
		{
			Thread.Sleep(ColdStartPollIntervalMs);

			if (VisualStudioDte.FindRunningInstance(SolutionPath) case .Ok(let startedDte))
			{
				VisualStudioDte.OpenFileAtLine(startedDte, FileName, LineNumber).IgnoreError();

				delete startedDte;
				return;
			}
		}

		Log.EngineLogger.Warning(scope $"Visual Studio was started but its automation interface never became available, \"{FileName}\" was not opened automatically.");
	}
}

#endif
