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

	public enum RunState
	{
		Ready,
		Blocked,
		Paused,
		Running,
		Aborted,
		Finished
	}
	 
	public enum RunResult
	{
		/// The task gives up it's runtime, but has to run again.
		Continue,
		/// The task gives up it's runtime, because it cannot continue without user intervention through the UI.
		Pause,
		/// The task finished and wont run again.
		Finished,
		/// The operation was aborted, the task will not run again.
		Abort
	}

    public RunState State { get; internal set; } = .Ready;

	public bool Ready => State == .Ready;
	public bool Paused => State == .Paused;
	public bool Blocked => State == .Blocked;
	public bool Running => State == .Running;
	public bool Aborted => State == .Aborted;
	public bool Finished => State == .Finished;

	public bool Ended => Finished || Aborted;

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
}
