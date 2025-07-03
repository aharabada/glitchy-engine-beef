using System;
using System.IO;
using System.Collections;
using System.Diagnostics;
using ImGui;
using System.Threading;

namespace GlitchyEditor.Multithreading;

class DeleteBackgroundTask : BackgroundTask
{
	private List<String> _sourcePath ~ {ClearAndDeleteItems!(_); delete:append _;};

	private int _totalEntriesToDelete;
	private append Queue<String> _pathsToDelete = .() ~ ClearAndDeleteItems!(_);
	private append Queue<String> _scanQueue = .() ~ ClearAndDeleteItems!(_);

	enum ConflictResolutionMode
	{
		None,
		IgnoreUnexpectedErrors = 1,
		SkipNotFound = 2
	}

	private ConflictResolutionMode _nextFileMode;
	private ConflictResolutionMode _allFilesMode;

	private ConflictResolutionMode CurrentFileMode => _nextFileMode | _allFilesMode;

	public bool ScanningFiles => !_scanQueue.IsEmpty;

	[AllowAppend]
	public this(Span<StringView> sourcePaths)
	{
		List<String> sourcePathList = append List<String>(sourcePaths.Length);

		_sourcePath = sourcePathList;

		for (StringView path in sourcePaths)
		{
			AddPath(path);
		}
	}

	public void AddPath(StringView pathToDelete)
	{
		_sourcePath.Add(new String(pathToDelete));
		_scanQueue.Add(new String(pathToDelete));
		_totalEntriesToDelete++;
	}

	public enum DeleteError : IDisposable
	{
		case None;
		case EntryNotFound(String SourcePath);
		case UnexpectedError(String Message);

		public void Dispose()
		{
			switch (this)
			{
			case .None:
			case .EntryNotFound(let SourcePath):
				delete SourcePath;
			case .UnexpectedError(let Message):
				delete Message;
			}
		}
	}

	private Result<void, DeleteError> CollectFiles()
	{
		String currentPath = null;
		defer
		{
			if (currentPath != null && @return case .Err)
			{
				_scanQueue.AddFront(currentPath);
			}
		}

		void AddToDeleteStack(String path)
		{
			_pathsToDelete.Add(path);
		}

		while (!_scanQueue.IsEmpty && Running)
		{
			// Pop from back, so that we delete children before parent directories
			currentPath = _scanQueue.PopBack();
			
			let fileName = scope String();
			Path.GetFileName(currentPath, fileName);

			if (Directory.Exists(currentPath))
			{
				// Current node is ready, add it to delete-queue.
				AddToDeleteStack(currentPath);
				
				// Add nested files and directories to the scan-queue.
				for (FileFindEntry e in Directory.Enumerate(currentPath))
				{
					let entryPath = new String();
					e.GetFilePath(entryPath);

					_scanQueue.Add(entryPath);
				}
			}
			else if (File.Exists(currentPath))
			{
				AddToDeleteStack(currentPath);
			}
		}

		_totalEntriesToDelete = _pathsToDelete.Count;

		return .Ok;
	}

	private DeleteError _currentError = .None ~ _.Dispose();

	public override RunResult Run()
	{
		_currentError.Dispose();
		_currentError = .None;
		if (CollectFiles() case .Err(out _currentError) || Paused)
		{
			return .Pause;
		}
		
		while (!_pathsToDelete.IsEmpty && Running)
		{
			String currentPath = _pathsToDelete.Back;

			if (DeletePath(currentPath) case .Err(out _currentError) || Paused)
			{
				return .Pause;
			}

			_pathsToDelete.PopBack();
			delete currentPath;
		}

		return .Finished;
	}

	private Result<void, DeleteError> DeletePath(StringView deletePath)
	{
		if (Directory.Exists(deletePath))
		{
			if (Directory.Delete(deletePath) case .Err(let err) &&
				!CurrentFileMode.HasFlag(.IgnoreUnexpectedErrors))
			{
				return .Err(.UnexpectedError(new $"Failed to delete directory {deletePath}: {err}"));
			}
		}
		else if (File.Exists(deletePath))
		{
			if (File.Delete(deletePath) case .Err(let err) &&
				!CurrentFileMode.HasFlag(.IgnoreUnexpectedErrors))
			{
				return .Err(.UnexpectedError(new $"Failed to delete file {deletePath}: {err}"));
			}
		}
		else
		{
			if (!CurrentFileMode.HasFlag(.SkipNotFound))
				return .Err(.EntryNotFound(new String(deletePath)));
		}

		return .Ok;
	}

	public override void OnRenderPopup()
	{
		String title = scope .("Deleting files...");

		if (ImGui.Begin(title, null, .NoDocking | .NoCollapse | .Modal | .NoResize | .AlwaysAutoResize))
		{
			if (ScanningFiles)
			{
				ImGui.ProgressBar(-1.0f * (float)ImGui.GetTime(), .(-1, 0), scope $"Found {_pathsToDelete.Count} files...");
			}
			else
			{
				int deletedEntries = _totalEntriesToDelete - _pathsToDelete.Count;

				ImGui.ProgressBar(deletedEntries / _totalEntriesToDelete, .(-1, 0), scope $"Deleted {deletedEntries} / {_totalEntriesToDelete} files.");
			}

			
			switch (_currentError)
			{
			case .EntryNotFound(let SourcePath):
				ImGui.PushStyleColor(.Text, 0xFF0000FF);
				ImGui.TextUnformatted(scope $"\"{SourcePath}\" doesn't exist.");
				ImGui.PopStyleColor();
			case .UnexpectedError(let Message):
				ImGui.PushStyleColor(.Text, 0xFF0000FF);
				ImGui.TextUnformatted(scope $"Unexpected error: {Message}");
				ImGui.PopStyleColor();
			default:
				// Do nothing
			}
			
			if (ImGui.BeginTable("buttonTable", 2))
			{
				switch (_currentError)
				{
				case .None:
					// Do nothing
				case .EntryNotFound(let SourcePath):
					ImGui.TableNextRow();
					ImGui.TableSetColumnIndex(0);
					if (ImGui.Button("Skip"))
					{
						_nextFileMode |= .SkipNotFound;
						Continue();
					}
					ImGui.TableSetColumnIndex(1);
					if (ImGui.Button("Skip all"))
					{
						_allFilesMode |= .SkipNotFound;
						Continue();
					}
				case .UnexpectedError(let Message):
					ImGui.TableNextRow();
					ImGui.TableSetColumnIndex(0);
					if (ImGui.Button("Retry"))
					{
						Continue();
					}
					ImGui.TableNextRow();
					ImGui.TableSetColumnIndex(0);
					if (ImGui.Button("Ignore"))
					{
						_nextFileMode |= .IgnoreUnexpectedErrors;
						Continue();
					}
					ImGui.TableSetColumnIndex(1);
					if (ImGui.Button("Ignore all unexpected"))
					{
						_allFilesMode |= .IgnoreUnexpectedErrors;
						Continue();
					}
				}
				
				ImGui.TableNextRow();
				ImGui.TableNextColumn();

				if (_currentError case .None)
				{
					if (Paused)
					{
						if (ImGui.Button("Continue"))
						{
							Continue();
						}
					}
					else
					{
						if (ImGui.Button("Pause"))
						{
							Pause();
						}
					}
	
					ImGui.SameLine();
				}
	
				if (ImGui.Button("Cancel"))
				{
					Abort();
				}
				ImGui.EndTable();
			}
			
			ImGui.End();
		}
	}
}
