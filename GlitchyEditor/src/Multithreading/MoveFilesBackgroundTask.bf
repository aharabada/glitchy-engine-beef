using System;
using System.IO;
using System.Collections;
using System.Diagnostics;
using ImGui;
using System.Threading;

namespace GlitchyEditor.Multithreading;

class MoveFilesBackgroundTask : BackgroundTask
{
	private List<String> _sourcePath ~ {ClearAndDeleteItems!(_); delete:append _;};
	private String _targetDirectoryPath ~ delete:append _;

	private int _totalEntriesToMove;
	private append Queue<CopyInfo> _pathsToMove = .() ~ ClearAndDeleteItems!(_);
	private append Queue<CopyInfo> _scanQueue = .() ~ ClearAndDeleteItems!(_);
	/// Contains the file paths, that will definitely exist after copying. This is used for file renaming during scanning.
	private append HashSet<StringView> _targetPaths = .();
	
	private enum ConflictResolutionMode
	{
		None,
		OverwriteFile = 1,
		KeepBoth = 2,
		CombineDirectories = 4,
		SkipFiles = 8,
		SkipDirectories = 16,
		SkipNotFound = 32,
		IgnoreUnexpectedErrors = 64
	}

	private ConflictResolutionMode _nextFileMode;
	private ConflictResolutionMode _allFilesMode;

	private ConflictResolutionMode CurrentFileMode => _nextFileMode | _allFilesMode;

	private class CopyInfo
	{
		public append String SourcePath = .();
		// If this entry is actually inside a directory we copy, this contains the path of this entry inside this directory.
		public append String SubPath = .();
		public append String TargetPath = .();
		public ConflictResolutionMode ConflictResolutionMode;

		[AllowAppend]
		public this(StringView sourcePath, StringView targetPath, ConflictResolutionMode conflictResolutionMode)
		{
			SourcePath.Set(sourcePath);
			TargetPath.Set(targetPath);
			ConflictResolutionMode = conflictResolutionMode;
		}
	}

	public bool ScanningFiles => !_scanQueue.IsEmpty;

	[AllowAppend]
	public this(List<String> sourcePaths, StringView targetDirectoryPath)
	{
		List<String> sourcePathList = append List<String>(sourcePaths.Count);
		String targetDirectoryPathStr = append String(targetDirectoryPath);

		_sourcePath = sourcePathList;
		_targetDirectoryPath = targetDirectoryPathStr;

		for (String path in sourcePaths)
		{
			_sourcePath.Add(new String(path));
			_scanQueue.Add(new CopyInfo(path, "", .None));
		}

		_totalEntriesToMove = sourcePaths.Count;
	}
	
	public enum CopyError : IDisposable
	{
		case None;
		case TargetDirectoryIsNotDirectory;
		case TargetFileExists(String FileName);
		case TargetDirectoryExists(String DirectoryName);
		case EntryNotFound(String SourcePath);
		case UnexpectedError(String Message);

		public void Dispose()
		{
			switch (this)
			{
			case .None:
			case .TargetDirectoryIsNotDirectory:
			case .TargetFileExists(let FileName):
				delete FileName;
			case .TargetDirectoryExists(let DirectoryName):
				delete DirectoryName;
			case .EntryNotFound(let SourcePath):
				delete SourcePath;
			case .UnexpectedError(let Message):
				delete Message;
			}
		}
	}

	private Result<void, CopyError> CollectFilesToMove()
	{
		CopyInfo currentEntry = null;
		defer
		{
			if (currentEntry != null && @return case .Err)
			{
				_scanQueue.AddFront(currentEntry);
			}
		}

		void AddToMoveQueue(CopyInfo entry, StringView targetPath, ConflictResolutionMode conflictResolutionMode)
		{
			entry.TargetPath.Set(targetPath);
			entry.ConflictResolutionMode = conflictResolutionMode;
			_pathsToMove.Add(entry);
			_targetPaths.Add(entry.TargetPath);
		}

		while (!_scanQueue.IsEmpty && Running)
		{
			currentEntry = _scanQueue.PopFront();
			
			let sourcePath = (StringView)currentEntry.SourcePath;

			let fileName = scope String();
			Path.GetFileName(sourcePath, fileName);

			let targetPath = scope String();
			Path.Combine(targetPath, _targetDirectoryPath, currentEntry.SubPath, fileName);

			if (Directory.Exists(sourcePath))
			{
				bool skip = false;

				if (Directory.Exists(targetPath) || _targetPaths.Contains(targetPath))
				{
					if (CurrentFileMode.HasFlag(.KeepBoth))
					{
						Path.FindFreePath(_targetDirectoryPath, fileName, "", targetPath, fileName, _targetPaths);
					}
					else if (CurrentFileMode.HasFlag(.SkipDirectories))
					{
						skip = true;
					}
					else if (Enum.HasAnyFlag(CurrentFileMode, .CombineDirectories))
					{
						// Intentionally do nothing.
					}
					else
					{
						return .Err(.TargetDirectoryExists(new String(fileName)));
					}
				}
				
				if (skip)
				{
					delete currentEntry;
				}
				else
				{
					// Current node is ready, add it to move-queue.
					AddToMoveQueue(currentEntry, targetPath, CurrentFileMode);

					if (Enum.HasAnyFlag(CurrentFileMode, .CombineDirectories))
					{
						// Add nested files and directories to the scan-queue.
						for (FileFindEntry e in Directory.Enumerate(currentEntry.SourcePath))
						{
							let entryPath = scope String();
							e.GetFilePath(entryPath);
	
							let newEntry = new CopyInfo(entryPath, targetPath, .None);
							_scanQueue.Add(newEntry);
	
							Path.Combine(newEntry.SubPath, currentEntry.SubPath, fileName);
						}
					}
				}

				_nextFileMode = .None;
			}
			else if (File.Exists(sourcePath))
			{
				bool skip = false;

				if (File.Exists(targetPath) || _targetPaths.Contains(targetPath))
				{
					if (CurrentFileMode.HasFlag(.KeepBoth))
					{
						let fileExtension = scope String();
						Path.GetExtension(targetPath, fileExtension);

						StringView fileNameWithoutExtension = fileName.Substring(0..<^fileExtension.Length);
	
						Path.FindFreePath(_targetDirectoryPath, fileNameWithoutExtension, fileExtension, targetPath, fileName, _targetPaths);
					}
					else if (CurrentFileMode.HasFlag(.SkipFiles))
					{
						skip = true;
					}
					else if (Enum.HasAnyFlag(CurrentFileMode, .OverwriteFile))
					{
						// Intentionally do nothing.
					}
					else
					{
						return .Err(.TargetFileExists(new String(fileName)));
					}
				}
				
				if (skip)
				{
					delete currentEntry;
				}
				else
				{
					AddToMoveQueue(currentEntry, targetPath, CurrentFileMode);
				}

				_nextFileMode = .None;
			}
		}

		_totalEntriesToMove = _pathsToMove.Count;

		return .Ok;
	}

	private CopyError _currentError = .None ~ _.Dispose();

	public override RunResult Run()
	{
		_currentError.Dispose();
		_currentError = .None;
		if (CollectFilesToMove() case .Err(out _currentError) || Paused)
		{
			return .Pause;
		}
		
		while (!_pathsToMove.IsEmpty && Running)
		{
			CopyInfo currentPath = _pathsToMove.Peek();

			if (MovePath(currentPath) case .Err(out _currentError) || Paused)
			{
				return .Pause;
			}

			_pathsToMove.PopFront();
			delete currentPath;
		}

		return .Finished;
	}

	private Result<void, CopyError> MovePath(CopyInfo copyInfo)
	{
		if (Directory.Exists(copyInfo.SourcePath))
		{
			if (Directory.Exists(copyInfo.TargetPath))
			{
				if (copyInfo.ConflictResolutionMode.HasFlag(.CombineDirectories))
				{
					// We don't have to do anything, because we will be using the target directory.
					return .Ok;
				}
				else if (!CurrentFileMode.HasFlag(.IgnoreUnexpectedErrors))
				{
					return .Err(.UnexpectedError(new $"The target directory already exists, but it wasn't properly handled during the scanning phase."));
				}
			}

			if (Directory.Move(copyInfo.SourcePath, copyInfo.TargetPath) case .Err(let err) &&
				!CurrentFileMode.HasFlag(.IgnoreUnexpectedErrors))
			{
				return .Err(.UnexpectedError(new $"Failed to move Directory {copyInfo.TargetPath}: {err}"));
			}
		}
		else if (File.Exists(copyInfo.SourcePath))
		{
			bool forceOverwrite = false;
			if (File.Exists(copyInfo.TargetPath))
			{
				if (copyInfo.ConflictResolutionMode.HasFlag(.OverwriteFile))
				{
					forceOverwrite = true;
				}
				else if (!CurrentFileMode.HasFlag(.IgnoreUnexpectedErrors))
				{
					return .Err(.UnexpectedError(new $"The target file already exists, but it wasn't properly handled during the scanning phase."));
				}
			}
			
			if (File.Move(copyInfo.SourcePath, copyInfo.TargetPath) case .Err(let err) &&
				!CurrentFileMode.HasFlag(.IgnoreUnexpectedErrors))
			{
				return .Err(.UnexpectedError(new $"Failed to move File {copyInfo.TargetPath}: {err}"));
			}
		}
		else
		{
			if (copyInfo.ConflictResolutionMode.HasFlag(.SkipNotFound))
				return .Ok;
			else
				return .Err(.EntryNotFound(new String(copyInfo.SourcePath)));
		}

		return .Ok;
	}

	public override void OnRenderPopup()
	{
		String title = scope .("Copying files...");

		if (ImGui.Begin(title, null, .NoDocking | .NoCollapse | .Modal | .NoResize | .AlwaysAutoResize))
		{
			if (ScanningFiles)
			{
				ImGui.ProgressBar(-1.0f * (float)ImGui.GetTime(), .(-1, 0), scope $"Found {_pathsToMove.Count} files...");
			}
			else
			{
				int copiedFiles = _totalEntriesToMove - _pathsToMove.Count;

				ImGui.ProgressBar(copiedFiles / _totalEntriesToMove, .(-1, 0), scope $"Copied {copiedFiles} / {_totalEntriesToMove} files.");
			}

			
			switch (_currentError)
			{
			case .TargetFileExists(let fileName):
				ImGui.PushStyleColor(.Text, 0xFF0000FF);
				ImGui.TextUnformatted(scope $"A file with the name \"{fileName}\" already exists.");
				ImGui.PopStyleColor();
			case .TargetDirectoryExists(let directoryName):
				ImGui.PushStyleColor(.Text, 0xFF0000FF);
				ImGui.TextUnformatted(scope $"A directory with the name \"{directoryName}\" already exists.");
				ImGui.PopStyleColor();
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
				case .TargetDirectoryIsNotDirectory:
					// This shouldn't be possible
					Debug.Break();
				case .TargetFileExists(let fileName):
					ImGui.TableNextRow();
					ImGui.TableSetColumnIndex(0);

					if (ImGui.Button("Overwrite the target file."))
					{
						_nextFileMode = .OverwriteFile;
						Continue();
					}
					ImGui.TableSetColumnIndex(1);
					if (ImGui.Button("Overwrite all conflicting target files."))
					{
						_allFilesMode |= .OverwriteFile;
						Continue();
					}
					
					ImGui.TableNextRow();
					ImGui.TableSetColumnIndex(0);

					if (ImGui.Button("Rename copied file."))
					{
						_nextFileMode = .KeepBoth;
						Continue();
					}
					ImGui.TableSetColumnIndex(1);
					if (ImGui.Button("Rename all conflicting copied files."))
					{
						_allFilesMode |= .KeepBoth;
						Continue();
					}
					
					ImGui.TableNextRow();
					ImGui.TableSetColumnIndex(0);

					if (ImGui.Button("Skip this file."))
					{
						_nextFileMode = .SkipFiles;
						Continue();
					}
					ImGui.TableSetColumnIndex(1);
					if (ImGui.Button("Skip all conflicting files."))
					{
						_allFilesMode |= .SkipFiles;
						Continue();
					}
					
				case .TargetDirectoryExists(let directoryName):
					ImGui.TableNextRow();
					ImGui.TableSetColumnIndex(0);
	
					if (ImGui.Button("Combine with target."))
					{
						_nextFileMode |= .CombineDirectories;
						Continue();
					}
					ImGui.TableSetColumnIndex(1);
					if (ImGui.Button("Combine all conflicting directories."))
					{
						_allFilesMode |= .CombineDirectories;
						Continue();
					}

					ImGui.TableNextRow();
					ImGui.TableSetColumnIndex(0);
					
					if (ImGui.Button("Rename copied directory."))
					{
						_nextFileMode |= .KeepBoth;
						Continue();
					}
					ImGui.TableSetColumnIndex(1);
					if (ImGui.Button("Rename all conflicting directories."))
					{
						_allFilesMode |= .KeepBoth;
						Continue();
					}
					
					ImGui.TableNextRow();
					ImGui.TableSetColumnIndex(0);

					if (ImGui.Button("Skip this directory."))
					{
						_nextFileMode |= .SkipDirectories;
						Continue();
					}
					ImGui.TableSetColumnIndex(1);
					if (ImGui.Button("Skip all conflicting directories."))
					{
						_allFilesMode |= .SkipFiles;
						Continue();
					}
				case .EntryNotFound(let SourcePath):
					if (ImGui.Button("Skip"))
					{
						_nextFileMode |= .SkipNotFound;
						Continue();
					}
					ImGui.SameLine();
					if (ImGui.Button("Skip all"))
					{
						_allFilesMode |= .SkipNotFound;
						Continue();
					}
				case .UnexpectedError(let Message):
					if (ImGui.Button("Retry"))
					{
						Continue();
					}
					ImGui.SameLine();
					if (ImGui.Button("Ignore"))
					{
						_nextFileMode |= .IgnoreUnexpectedErrors;
						Continue();
					}
					ImGui.SameLine();
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
