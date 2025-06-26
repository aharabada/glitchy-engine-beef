using System;
using System.Diagnostics;

namespace GlitchyEditor.Multithreading;

using internal GlitchyEditor.Multithreading;

class BackgroundTaskList
{
	BackgroundTask _sentinel = new BackgroundTask()
	{
		public override BackgroundTask.RunResult Run() => .Finished;
		public override void OnRenderPopup() { }
		_next = _,
		_previous = _,
		_list = this
	} ~ delete _;

	private int _count;

	public BackgroundTask First => _sentinel._next == _sentinel ? null : _sentinel._next;
	public BackgroundTask Last => _sentinel._previous == _sentinel ? null : _sentinel._previous;
	public BackgroundTask End => _sentinel;

	public int Count => _count;

	private void InsertBefore(BackgroundTask item, BackgroundTask beforeNode)
	{
		item._next = beforeNode;
		item._previous = beforeNode._previous;
		item._next._previous = item;
		item._previous._next = item;

		item._list = this;

		_count++;

		Validate();
	}

	public void AddFirst(BackgroundTask item)
	{
		if (item._list != null)
			item._list.Remove(item, false);

		InsertBefore(item, _sentinel._next);
	}

	public void AddLast(BackgroundTask item)
	{
		if (item._list != null)
			item._list.Remove(item, false);

		InsertBefore(item, _sentinel);
	}

	public void Clear()
	{
		Clear(false);
	}

	public void Clear(bool deleteElements)
	{
		BackgroundTask task = _sentinel._next;

		while (task != _sentinel)
		{
			BackgroundTask nextTask = task._next;

			UnlinkElement(task);
			if (deleteElements)
				delete task;

			task = nextTask;
		}

		_sentinel._next = _sentinel._previous = _sentinel;

		_count = 0;

		Validate();
	}

	private void UnlinkElement(BackgroundTask element)
	{
		element._next = null;
		element._previous = null;
		element._list = null;
	}

	public bool Contains(BackgroundTask item)
	{
		return item._list == this;
	}

	public bool Remove(BackgroundTask item)
	{
		return Remove(item, false);
	}

	public bool Remove(BackgroundTask item, bool deleteElement)
	{
		if (item._list != this)
			return false;

		item._previous._next = item._next;
		item._next._previous = item._previous;

		UnlinkElement(item);

		if (deleteElement)
			delete item;

		_count--;

		Validate();

		return true;
	}

	public Result<BackgroundTask> TryPopFront()
	{
		if (_sentinel._next == _sentinel)
			return .Err;

		BackgroundTask first = _sentinel._next;

		Remove(first, false);

		return first;
	}

	public Result<BackgroundTask> TryPopBack()
	{
		if (_sentinel._previous == _sentinel)
			return .Err;

		BackgroundTask first = _sentinel._previous;

		Remove(first, false);

		return first;
	}

	internal void Validate()
	{
		BackgroundTask task = _sentinel._next;

		int visitedNodes = 0;

		while (task != _sentinel)
		{
			visitedNodes++;

			Debug.Assert(visitedNodes <= Count);
			Debug.Assert(task._list == this);

			BackgroundTask nextTask = task._next;

			Debug.Assert(nextTask._previous == task);
			task = nextTask;
		}

		Debug.Assert(visitedNodes == Count);
	}
}

class BackgroundTaskListTests
{
	// Stub implementation
	class BackgroundTask : GlitchyEditor.Multithreading.BackgroundTask
	{
		public override BackgroundTask.RunResult Run()
		{
			return default;
		}

		public override void OnRenderPopup()
		{

		}
	}

    static void TestBasicOperations()
    {
        Debug.WriteLine("🧪 Testing Basic Operations...");
        
        var list1 = scope BackgroundTaskList();
        
        var task1 = scope BackgroundTask();
        var task2 = scope BackgroundTask();
        
        // Test AddFirst
        list1.AddFirst(task1);
        Debug.Assert(list1.Count == 1);
        Debug.Assert(task1._list == list1);
        Debug.Assert(list1.Contains(task1));
		list1.Validate();
        
        // Test AddLast
        list1.AddLast(task2);
        Debug.Assert(list1.Count == 2);
        Debug.Assert(task2._list == list1);
        Debug.Assert(list1.Contains(task2));
		list1.Validate();
        
        // Test Remove
        list1.Remove(task1);
        Debug.Assert(list1.Count == 1);
        Debug.Assert(task1._list == null);
        Debug.Assert(!list1.Contains(task1));
        Debug.Assert(list1.Contains(task2));
		list1.Validate();
        
        Debug.WriteLine("✅ Basic Operations passed!");
    }
    
    static void TestAutoRemoveFromOldList()
    {
        Debug.WriteLine("🧪 Testing Auto-Remove from Old List...");
        
        var list1 = scope BackgroundTaskList();
        var list2 = scope BackgroundTaskList();
        
        var task = scope BackgroundTask();
        
        // Add to list1
        list1.AddFirst(task);
        Debug.Assert(list1.Count == 1);
        Debug.Assert(list2.Count == 0);
        Debug.Assert(task._list == list1);
		list1.Validate();
		list2.Validate();
        
        // Add to list2 - should remove from list1
        list2.AddLast(task);
        Debug.Assert(list1.Count == 0);
        Debug.Assert(list2.Count == 1);
        Debug.Assert(task._list == list2);
        Debug.Assert(!list1.Contains(task));
        Debug.Assert(list2.Contains(task));
		list1.Validate();
		list2.Validate();
        
        // add to list1 again, should be removed from list2
        list1.AddFirst(task);
        Debug.Assert(list1.Count == 1);
        Debug.Assert(list2.Count == 0);
        Debug.Assert(task._list == list1);
		list1.Validate();
		list2.Validate();
        
        Debug.WriteLine("✅ Auto-Remove passed!");
    }
    
    static void TestTryPopFront()
    {
        Debug.WriteLine("🧪 Testing TryPopFront...");
        
        var list = scope BackgroundTaskList();
        
        // Test empty list
        let emptyResult = list.TryPopFront();
        Debug.Assert(emptyResult == .Err);
		list.Validate();
        
        var task1 = scope BackgroundTask();
        var task2 = scope BackgroundTask();
        var task3 = scope BackgroundTask();
        
        // Add three elements
        list.AddLast(task1);
		list.Validate();
        list.AddLast(task2);
		list.Validate();
        list.AddLast(task3);
		list.Validate();
        Debug.Assert(list.Count == 3);
        
        // Pop first element
        let pop1 = list.TryPopFront();
        Debug.Assert(pop1 == .Ok(task1));
        Debug.Assert(list.Count == 2);
        Debug.Assert(task1._list == null);
		list.Validate();
        
        // Pop second element
        let pop2 = list.TryPopFront();
        Debug.Assert(pop2 == .Ok(task2));
        Debug.Assert(list.Count == 1);
        Debug.Assert(task2._list == null);
		list.Validate();
        
        // Pop third element
        let pop3 = list.TryPopFront();
        Debug.Assert(pop3 == .Ok(task3));
        Debug.Assert(list.Count == 0);
        Debug.Assert(task3._list == null);
		list.Validate();
        
        // Pop on now empty list
        let pop4 = list.TryPopFront();
        Debug.Assert(pop4 == .Err);
		list.Validate();
        
        Debug.WriteLine("✅ TryPopFront passed!");
    }
    
    /*static void TestIterator()
    {
        Debug.WriteLine("🧪 Testing Iterator...");
        
        var list = scope BackgroundTaskList();
        var tasks = scope BackgroundTask*[5];
        
        for (int i = 0; i < tasks.Count; i++)
        {
            tasks[i] = new BackgroundTask();
            list.AddLast(tasks[i]);
        }
        defer { for (var t in tasks) delete t; }
        
        // Teste Iterator
        int count = 0;
        for (var task in list)
        {
            Debug.Assert(task == tasks[count]);
            count++;
        }
        Debug.Assert(count == 5);
        
        Debug.WriteLine("✅ Iterator passed!");
    }*/
    
    static void TestClear()
    {
        Debug.WriteLine("🧪 Testing Clear...");
        
        var list = scope BackgroundTaskList();

        var task1 = scope BackgroundTask();
        var task2 = scope BackgroundTask();
        var task3 = scope BackgroundTask();
        
        list.AddLast(task1);
		list.Validate();
        list.AddLast(task2);
		list.Validate();
        list.AddLast(task3);
		list.Validate();
        Debug.Assert(list.Count == 3);
        
        // Clear sollte task1 und task3 löschen, aber nicht task2
        list.Clear();
        Debug.Assert(list.Count == 0);
		list.Validate();
        
        Debug.WriteLine("✅ Clear passed!");
    }
    
    static void TestComplexScenario()
    {
		// Simulate processing queues.
        Debug.WriteLine("🧪 Testing Complex Scenario...");
        
        var pending = scope BackgroundTaskList();
        var processing = scope BackgroundTaskList();
        var completed = scope BackgroundTaskList();

		// Add to pending
        var tasks = scope BackgroundTask[10];
        for (int i = 0; i < tasks.Count; i++)
        {
            tasks[i] = scope:: BackgroundTask();
            pending.AddLast(tasks[i]);
			pending.Validate();
        }
        
        // Move from pending to processing
        while (true)
        {
            let result = pending.TryPopFront();
            if (result == .Err) break;
            
            let task = result.Value;
            processing.AddLast(task);
			processing.Validate();
        }
        
        Debug.Assert(pending.Count == 0);
        Debug.Assert(processing.Count == 10);
        
		// Move to completed
        while (true)
        {
            let result = processing.TryPopFront();
            if (result == .Err) break;
            
            completed.AddLast(result.Value);
			completed.Validate();
        }
        
        Debug.Assert(processing.Count == 0);
        Debug.Assert(completed.Count == 10);
        
        Debug.WriteLine("✅ Complex Scenario passed!");
    }
    
    public static void RunTests()
    {
        Debug.WriteLine("🚀 Starting BackgroundTaskList Tests...\n");
        
        TestBasicOperations();
        TestAutoRemoveFromOldList();
        TestTryPopFront();
        //TestIterator();
        TestClear();
        TestComplexScenario();
        
        Debug.WriteLine("\n🎉 All tests passed!");
    }
}