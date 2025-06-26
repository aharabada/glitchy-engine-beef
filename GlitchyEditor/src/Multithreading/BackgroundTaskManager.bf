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

	private append Dictionary<BackgroundTask, BackgroundTask.RunState> _deferredStateChanges = .();

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

				if (_deferredStateChanges.TryGetValue(task, let desiredState))
				{
					// If the task already finished or aborted by itself, we don't care about the desired state, because it no longer applies.
					if (runResult != .Finished && runResult != .Abort)
					{
						switch (desiredState)
						{
						case .Paused:
							runResult = .Pause;
						case .Aborted:
							runResult = .Abort;
						default:
							Log.EngineLogger.Error($"Tasks can't explicitly switch to state {desiredState}.");
						}
					}

					_deferredStateChanges.Remove(task);
				}
				
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
		
					if (task.DeleteWhenEnded)
					{
						delete task;
					}
				case .Abort:
					task.State = .Aborted;

					if (task.DeleteWhenEnded)
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

		if (task.State == .Paused)
		{
			_deferredStateChanges.Add(task, .Ready);
		}
	}
	
	internal void Pause(BackgroundTask task)
	{
		Log.EngineLogger.AssertDebug(task._taskManager == this);
		Log.EngineLogger.AssertDebug(!task.Ended);
		
		if (task.State == .Ready || task.State == .Running)
		{
			_deferredStateChanges.Add(task, .Paused);
		}
	}
	
	internal void AbortTask(BackgroundTask task)
	{
		Log.EngineLogger.AssertDebug(task._taskManager == this);
		Log.EngineLogger.AssertDebug(!task.Ended);
		
		if (task.State != .Aborted)
		{
			_deferredStateChanges.Add(task, .Aborted);
		}
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

			for (var (task, desiredState) in _deferredStateChanges)
			{
				bool deleteEntry = true;

				switch (desiredState)
				{
				case .Ready:
					task.State = .Ready;
					// We assume this was a user interaction so this task will get priority.
					_readyQueue.AddFirst(task);
				case .Paused:
					if (task.Ready)
					{
						Log.EngineLogger.AssertDebug(!_waitingTasks.Contains(task));
						_waitingTasks.AddLast(task);
					}
					else if (task.Running)
					{
						// The task is running, we have to hope that it cooperates and handle the rest in the worker thread.
						deleteEntry = false;
					}

					task.State = .Paused;
				case .Aborted:
					if (task.Ready || task.Paused)
					{
						_waitingTasks.Remove(task);
						
						task.State = .Aborted;

						if (task.DeleteWhenEnded)
						{
							delete task;
							task = null;
						}
					}
					else if (task.Running)
					{
						task.State = .Aborted;

						// The task is running, we have to hope that it cooperates and handle the rest in the worker thread.
						deleteEntry = false;
					}
				default:
					Log.EngineLogger.Error($"Tasks can't explicitly switch to state {desiredState}.");
				}

				if (deleteEntry)
				{
					@task.Remove();
				}	
			}
		}
	}
}