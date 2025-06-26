using System;
using System.Threading;
using System.Collections;
using GlitchyEngine;
using GlitchyEngine.Collections;

namespace GlitchyEditor.Multithreading;

using internal GlitchyEditor.Multithreading;

// This would go nicely with some light weight threading!
class BackgroundTaskManager
{
	private Thread _workerThread;

	private bool _run;

	private BackgroundTask _runningTask;
	private append BackgroundTaskList _readyQueue = .();
	private append BackgroundTaskList _waitingTasks = .();
	private append Monitor _queueLock = .();

	public void Init()
	{
		_run = true;
		_workerThread = new Thread(new => WorkerLoop);
		_workerThread.Start();
	}
	
	public void Deinit()
	{
		_run = false;

		// TODO: Delete jobs if necessary
		// TODO: Danger if thread is deadlocked.
		_workerThread.Join();
	}

	private void WorkerLoop()
	{
		while (_run)
		{
			Result<BackgroundTask> nextRunningTask = .Err;

			using (_queueLock.Enter())
			{
				nextRunningTask = _readyQueue.TryPopFront();
			}

			if (nextRunningTask case .Ok(let task))
			{
				_runningTask = task;
				_runningTask.State = .Running;
				BackgroundTask.RunResult runResult = task.Run();
				_runningTask = null;

				switch (runResult)
				{
				case .Continue:
					task.State = .Ready;
					using (_queueLock.Enter())
					{
						_readyQueue.AddLast(task);
					}
				case .Pause:
					task.State = .Paused;
					using (_queueLock.Enter())
					{
						_waitingTasks.AddLast(task);
					}
				case .Finished:
					task.State = .Finished;
		
					if (task.DeleteWhenStopped)
					{
						delete task;
					}
				case .Abort:
					task.State = .Aborted;

					if (task.DeleteWhenStopped)
					{
						delete task;
					}
				}
			}
            else
			{
				Thread.Sleep(10);
			}
		}
	}

	public Result<void> StartBackgroundTask(BackgroundTask task)
	{
		if (task._taskManager != null)
		{
			Log.EngineLogger.Error("Task is already managed by a taskmanager.");
			return .Err;
		}

		if (task.State == .Running || task.State == .Aborted)
		{
			Log.EngineLogger.Error("Task State illegal. (Did it already run?)");
			return .Err;
		}

		task._taskManager = this;

		using (_queueLock.Enter())
		{
			if (task.State == .Ready)
				_readyQueue.AddLast(task);
			else
				_waitingTasks.AddLast(task);
		}

		return .Ok;
	}

	internal void ContinueTask(BackgroundTask task)
	{
		Log.EngineLogger.AssertDebug(task._taskManager == this);
		Log.EngineLogger.AssertDebug(!task.Ended);

		Application.Instance.InvokeOnMainThread(new () =>
			{
				if (task.State == .Paused)
				{
					task.State = .Ready;
		
					using (_queueLock.Enter())
					{
						Log.EngineLogger.AssertDebug(!_readyQueue.Contains(task));
						// We assume this was a user interaction so this task will get some priority.
						_readyQueue.AddFirst(task);
					}
				}
				return true;
			});
	}
	
	internal void Pause(BackgroundTask task)
	{
		Log.EngineLogger.AssertDebug(task._taskManager == this);
		Log.EngineLogger.AssertDebug(!task.Ended);
		
		Application.Instance.InvokeOnMainThread(new () =>
			{
				if (task.State == .Ready)
				{
					task.State = .Ready;

					using (_queueLock.Enter())
					{
						Log.EngineLogger.AssertDebug(!_waitingTasks.Contains(task));
						_waitingTasks.AddLast(task);
					}
				}
				return true;
			});
	}
	
	internal void AbortTask(BackgroundTask task)
	{
		Log.EngineLogger.AssertDebug(task._taskManager == this);
		Log.EngineLogger.AssertDebug(!task.Ended);
		
		Application.Instance.InvokeOnMainThread(new () =>
			{
				if (task.State != .Aborted)
				{
					task.State = .Aborted;

					using (_queueLock.Enter())
					{
						_waitingTasks.Remove(task);
					}

					if (task.DeleteWhenStopped)
					{
						delete task;
					}
				}
				return true;
			});
	}

	public void ImGuiRender()
	{
		using (_queueLock.Enter())
		{
			_runningTask?.OnRenderPopup();

			BackgroundTask task = _readyQueue.First;

			while (task != null && task != _readyQueue.End)
			{
				Log.EngineLogger.Assert(task._list == _readyQueue); 

				task.OnRenderPopup();
				task = task._next;
			}
			
			BackgroundTask wtask = _waitingTasks.First;
			
			while (wtask != null && wtask != _waitingTasks.End)
			{
				Log.EngineLogger.Assert(wtask._list == _waitingTasks); 

				wtask.OnRenderPopup();
				wtask = wtask._next;
			}
		}
	}
}