using System;
using System.IO;
using System.Threading;
using System.Collections;
using System.Diagnostics;
using ImGui;

namespace GlitchyEditor.Multithreading;

using internal GlitchyEditor.Multithreading;

abstract class BackgroundTask
{
	internal BackgroundTaskList _list;
	internal BackgroundTask _previous;
	internal BackgroundTask _next;

	internal BackgroundTaskManager _taskManager;

	public delegate void Continuation(BackgroundTask);

	internal append List<(TaskContinuationOptions ContinuationOptions, Continuation Continuation)> _continuations = .() ~ {
		for (let entry in _)
		{
			delete entry.Continuation;
		}
	};

	public enum RunState
	{
		Ready,
		Blocked,
		Paused,
		Running,
		Aborted,
		Finished,
		Failed
	}
	 
	public enum RunResult
	{
		/// The task gives up it's runtime, but has to run again.
		Continue,
		/// The task gives up it's runtime, because it cannot continue without user intervention through the UI.
		Pause,
		/// The task finished and wont run again.
		Finish,
		/// The operation was aborted, the task will not run again.
		Abort,
		/// The task failed and wont run again.
		Fail
	}

    public RunState State { get; internal set; } = .Ready;

	public bool Ready => State == .Ready;
	public bool Paused => State == .Paused;
	public bool Blocked => State == .Blocked;
	public bool Running => State == .Running;
	public bool Aborted => State == .Aborted;
	public bool Failed => State == .Failed;
	public bool Finished => State == .Finished;

	public bool Ended => Finished || Aborted || Failed;

	public bool DeleteWhenEnded { get; set; }

	public abstract RunResult Run();

	public abstract void OnRenderPopup();

	public void Continue()
	{
		_taskManager.ContinueTask(this);
	}

	public void Pause()
	{
		_taskManager.Pause(this);
	}

	public void Abort()
	{
		_taskManager.AbortTask(this);
	}

	public enum TaskContinuationOptions
	{
		/// Same as Default
		None = 0,

		RunOnFinished = 1,
		RunOnFailed = 2,
		RunOnAborted = 4,

		Default = RunOnFinished | RunOnFailed | RunOnAborted
	}

	/// Creates a continuation that executes when the target Task completes.
	public void ContinueWith(Continuation ownContinuation, TaskContinuationOptions continuationOptions = .Default)
	{
		var continuationOptions;

		if (continuationOptions == .None)
		{
			continuationOptions = .Default;
		}

		if (Ended)
		{
			ownContinuation(this);
		}
		else
		{
			_continuations.Add((continuationOptions, ownContinuation));
		}
	}
}
