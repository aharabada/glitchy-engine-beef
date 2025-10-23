namespace BuildTool;

class WorkingDirectoryHistory
{
	private List<string> _history = new();
	private int _currentIndex = -1;

	public int CurrentIndex => _currentIndex;
	public int HistoryLength => _history.Count;

	public IReadOnlyCollection<string> History => _history.AsReadOnly();

	public string CurrentDirectoryPath => _currentIndex >= 0 ? _history[_currentIndex] : "";
	public string WorkspaceRoot => _history[0];

	public bool CanGoBack => _currentIndex > 0;
	public bool CanGoForward => (_currentIndex + 1) < _history.Count;

	public WorkingDirectoryHistory(string rootPath)
	{
		Navigate(rootPath);
	}

	public void ApplyCurrentDirectory()
	{
		Directory.SetCurrentDirectory(CurrentDirectoryPath);
	}

	public void Navigate(string nextPath)
	{
		if (!Path.IsPathRooted(nextPath))
		{
			nextPath = Path.Combine(CurrentDirectoryPath, nextPath);
			InternalNavigate(nextPath);
		}

		InternalNavigate(nextPath);
	}

	public void NavigateFromWorkspaceRoot(string nextPath)
	{
		if (Path.IsPathRooted(nextPath))
		{
			throw new ArgumentException("Cannot navigate from a root path other than its working directory.");
		}

		nextPath = Path.Combine(WorkspaceRoot, nextPath);
		InternalNavigate(nextPath);
	}

	private void InternalNavigate(string nextPath)
	{
		nextPath =  Path.GetFullPath(nextPath);

		_currentIndex++;
		_history.Insert(_currentIndex, nextPath);
		TrimHistory();
		ApplyCurrentDirectory();
	}

	private void TrimHistory()
	{
		_history.RemoveRange(_currentIndex + 1, _history.Count - _currentIndex - 1);
	}

	public void Replace(string nextPath)
	{
		if (_currentIndex == -1)
		{
			_currentIndex = 0;
			_history.Insert(_currentIndex, nextPath);
		}
		else
		{
			_history[_currentIndex] = nextPath;
		}

		TrimHistory();
		ApplyCurrentDirectory();
	}

	public bool Back()
	{
		if (CanGoBack)
		{
			_currentIndex--;
			ApplyCurrentDirectory();
			return true;
		}
		return false;
	}

	public bool Forward()
	{
		if (CanGoForward)
		{
			_currentIndex++;
			ApplyCurrentDirectory();
			return true;
		}
		return false;
	}

	public bool NavigateToIndex(int index)
	{
		if (index < 0)
			return false;

		if (index >= _history.Count)
			return false;

		_currentIndex = index;
		ApplyCurrentDirectory();

		return true;
	}

	public string GetRelativePath(string path)
	{
		return Path.GetFullPath(Path.Combine(CurrentDirectoryPath, path));
	}

	public string GetPathRelativeToRoot(string path)
	{
		return Path.GetFullPath(Path.Combine(WorkspaceRoot, path));
	}
}