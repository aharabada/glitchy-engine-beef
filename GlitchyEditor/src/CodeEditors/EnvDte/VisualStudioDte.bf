#if BF_PLATFORM_WINDOWS

using System;
using System.Threading;
using DirectX.Common;
using GlitchyEngine;
using GlitchyEditor.Platform.Windows.Com;
using System.IO;

namespace GlitchyEditor.CodeEditors;

/// Talks to running Visual Studio instances via their EnvDTE automation objects, which are
/// published in the Running Object Table as "!VisualStudio.DTE.<version>:<pid>".
/// All methods must be called from a thread that is initialized for COM (CoInitializeEx).
static class VisualStudioDte
{
	private const String MonikerPrefix = "!VisualStudio.DTE";
	/// EnvDTE.Constants.vsViewKindCode
	private const String ViewKindCode = "{7651A701-06E5-11D1-8EBD-00A0C90F26EA}";

	/// Searches the Running Object Table for a Visual Studio instance that has the given solution open.
	public static Result<ComDispatch> FindRunningInstance(StringView solutionPath)
	{
		IRunningObjectTable* rot = null;
		if (GetRunningObjectTable(0, out rot).Failed(var result) || rot == null)
		{
			Log.EngineLogger.Error(scope $"GetRunningObjectTable failed: {result} ({(uint32)result:X8})");
			return .Err;
		}

		defer rot.Release();

		IBindCtx* bindCtx = null;
		if (CreateBindCtx(0, out bindCtx).Failed(out result) || bindCtx == null)
		{
			Log.EngineLogger.Error(scope $"CreateBindCtx failed: {result} ({(uint32)result:X8})");
			return .Err;
		}

		defer bindCtx.Release();

		IEnumMoniker* enumMoniker = null;
		if (rot.EnumRunning(out enumMoniker).Failed(out result) || enumMoniker == null)
		{
			Log.EngineLogger.Error(scope $"IRunningObjectTable.EnumRunning failed: {result} ({(uint32)result:X8})");
			return .Err;
		}

		defer enumMoniker.Release();

		IMoniker* moniker = null;
		while (enumMoniker.Next(1, out moniker, ?) == .S_OK)
		{
			ComDispatch dte = GetDteFromMoniker(rot, bindCtx, moniker);

			ReleaseAndNullify!(moniker);

			if (dte == null)
				continue;

			String solutionFullName = scope .();

			if (TryGetSolutionFullName(dte, solutionFullName))
			{
				Log.EngineLogger.Trace(scope $"Found running Visual Studio instance with solution \"{solutionFullName}\".");

				if (SolutionPathsEqual(solutionFullName, solutionPath))
					return dte;
			}

			// No match, cleanup.
			delete dte;
		}

		return .Err;
	}

	/// Brings the main window of the given Visual Studio instance to the foreground.
	public static void ActivateMainWindow(ComDispatch dte)
	{
		if (!(dte.GetObjectProperty("MainWindow") case .Ok(let mainWindow)))
		{
			Log.EngineLogger.Warning("Failed to get the Visual Studio main window.");
			return;
		}

		defer delete mainWindow;

		if (mainWindow.InvokeMethod("Activate") case .Ok(var activateResult))
			VariantClear(&activateResult);

		// Activate alone often isn't enough to raise a window of another process,
		// so additionally restore and foreground it via its HWND.
		if (mainWindow.GetProperty("HWnd") case .Ok(var hwndValue))
		{
			if (hwndValue.GetHwnd() case .Ok(let hwnd))
			{
				if (IsIconic(hwnd))
					ShowWindow(hwnd, SW_RESTORE);

				SetForegroundWindow(hwnd);
			}

			VariantClear(&hwndValue);
		}
	}

	/// Opens the given file in the code editor of the given Visual Studio instance and
	/// jumps to lineNumber (1-based, ignored if <= 0).
	public static Result<void> OpenFileAtLine(ComDispatch dte, StringView fileName, int lineNumber)
	{
		ComDispatch itemOperations = Try!(dte.GetObjectProperty("ItemOperations"));
		defer delete itemOperations;

		VARIANT[] openFileArgs = scope .(VARIANT.FromBStr(fileName), VARIANT.FromBStr(ViewKindCode));

		if (itemOperations.InvokeMethod("OpenFile", openFileArgs) case .Ok(var window))
		{
			VariantClear(&window);
		}
		else
		{
			Log.EngineLogger.Error(scope $"Failed to open \"{fileName}\" in Visual Studio.");
			return .Err;
		}

		if (lineNumber > 0)
			GoToLine(dte, lineNumber);

		ActivateMainWindow(dte);

		return .Ok;
	}

	private static ComDispatch GetDteFromMoniker(IRunningObjectTable* rot, IBindCtx* bindCtx, IMoniker* moniker)
	{
		char16* displayNameW = null;

		if (moniker.GetDisplayName(bindCtx, null, out displayNameW).Failed || displayNameW == null)
			return null;

		String displayName = scope .();
		displayName.Append(displayNameW);
		CoTaskMemFree(displayNameW);

		if (!displayName.StartsWith(MonikerPrefix))
			return null;

		IUnknown* unknown = null;
		defer { unknown?.Release(); }

		if (rot.GetObject(moniker, out unknown).Failed || unknown == null)
			return null;

		IDispatch* dispatch = null;

		if (unknown.QueryInterface<IDispatch>(out dispatch).Succeeded)
			return new ComDispatch(dispatch);

		return null;
	}

	private static bool TryGetSolutionFullName(ComDispatch dte, String outFullName)
	{
		if (!(dte.GetObjectProperty("Solution") case .Ok(let solution)))
			return false;

		defer delete solution;

		return solution.GetStringProperty("FullName", outFullName) case .Ok;
	}

	private static bool SolutionPathsEqual(StringView left, StringView right)
	{
		String normalizedLeft = NormalizePath(left, .. scope .());
		String normalizedRight = NormalizePath(right, .. scope .());

		// Be tolerant about the solution extension: it isn't guaranteed that the DTE reports
		// the same extension for .slnx solutions that we expect.
		return StripSolutionExtension(normalizedLeft) == StripSolutionExtension(normalizedRight);
	}

	private static void NormalizePath(StringView path, String output)
	{
		output.Append(path);
		output.Replace('/', '\\');
		output.ToLower();
	}

	private static StringView StripSolutionExtension(StringView path)
	{
		if (path.EndsWith(".slnx"))
			return path.Substring(0, path.Length - ".slnx".Length);

		if (path.EndsWith(".sln"))
			return path.Substring(0, path.Length - ".sln".Length);

		return path;
	}

	private static void GoToLine(ComDispatch dte, int lineNumber)
	{
		ComDispatch document = null;
		defer { delete document; }
		
		// Directly after OpenFile the ActiveDocument might not be set yet, so retry for a bit.
		for (int i < 10)
		{
			if (dte.GetObjectProperty("ActiveDocument") case .Ok(out document))
				break;

			Thread.Sleep(100);
		}

		if (document == null)
		{
			Log.EngineLogger.Warning("Could not jump to the requested line: no active document.");
			return;
		}

		if (document.GetObjectProperty("Selection") not case .Ok(let selection))
		{
			Log.EngineLogger.Warning("Could not jump to the requested line: failed to get the text selection.");
			return;
		}

		VARIANT[2] gotoLineArgs = .(VARIANT.FromInt32((int32)lineNumber), VARIANT.FromBool(false));

		if (selection.InvokeMethod("GotoLine", gotoLineArgs) case .Ok(var gotoResult))
			VariantClear(&gotoResult);

		delete selection;
	}
}

#endif
