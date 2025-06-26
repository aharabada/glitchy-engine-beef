using System;
using System.IO;
using System.Collections;
using System.Diagnostics;
using ImGui;

namespace GlitchyEditor.Multithreading;

class CopyBackgroundTask : BackgroundTask
{
	private List<String> _sourcePath ~ {ClearAndDeleteItems!(_); delete:append _;};
	private String _targetDirectoryPath ~ delete:append _;

	private int _totalEntriesToCopy;
	private append Queue<CopyInfo> _pathsToCopy = .() ~ ClearAndDeleteItems!(_);
	private append Queue<CopyInfo> _scanQueue = .() ~ ClearAndDeleteItems!(_);
	
	private enum OverwriteMode
	{
		None,
		OverwriteFile = 1,
		KeepBoth = 2,
		CombineDirectories = 4,
		Skip = 8
	}

	private OverwriteMode _nextFileMode;
	private OverwriteMode _allFilesMode;

	private OverwriteMode CurrentFileMode => _nextFileMode | _allFilesMode;

	private class CopyInfo
	{
		public append String SourcePath = .();
		// If this entry is actually inside a directory we copy, this contains the path of this entry inside this directory.
		public append String SubPath = .();
		public append String TargetPath = .();
		public OverwriteMode OverwriteMode;

		[AllowAppend]
		public this(StringView sourcePath, StringView targetPath, OverwriteMode overwriteMode)
		{
			SourcePath.Set(sourcePath);
			TargetPath.Set(targetPath);
			OverwriteMode = overwriteMode;
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

		_totalEntriesToCopy = sourcePaths.Count;
	}
	
	public enum CopyError : IDisposable
	{
		case None;
		case TargetDirectoryIsNotDirectory;
		case SourceDoesntExist(String SourcePath);
		case TargetFileExists(String FileName);
		case TargetDirectoryExists(String DirectoryName);

		public void Dispose()
		{
			switch (this)
			{
			case .None:
			case .TargetDirectoryIsNotDirectory:
			case .SourceDoesntExist(let SourcePath):
				delete SourcePath;
			case .TargetFileExists(let FileName):
				delete FileName;
			case .TargetDirectoryExists(let DirectoryName):
				delete DirectoryName;
			}
		}
	}

	private Result<void, CopyError> CollectFilesToCopy()
	{
		CopyInfo currentEntry = null;
		defer
		{
			if (currentEntry != null && @return case .Err)
			{
				_scanQueue.AddFront(currentEntry);
			}
		}

		while (!_scanQueue.IsEmpty && Running)
		{
			//Thread.Sleep(1000);

			currentEntry = _scanQueue.PopFront();
			
			let sourcePath = (StringView)currentEntry.SourcePath;

			let fileName = scope String();
			Path.GetFileName(sourcePath, fileName);

			let targetPath = scope String();
			Path.Combine(targetPath, _targetDirectoryPath, currentEntry.SubPath, fileName);

			if (Directory.Exists(sourcePath))
			{
				if (Directory.Exists(targetPath))
				{
					switch (CurrentFileMode)
					{
					case .KeepBoth, .CombineDirectories, .Skip:
					default:
						return .Err(.TargetDirectoryExists(new String(fileName)));
					}
				}
				
				if (!CurrentFileMode.HasFlag(.Skip))
				{
					_pathsToCopy.Add(currentEntry);
					currentEntry.OverwriteMode = CurrentFileMode;
					for (FileFindEntry e in Directory.Enumerate(currentEntry.SourcePath))
					{
						let entryPath = scope String();
						e.GetFilePath(entryPath);

						let newEntry = new CopyInfo(entryPath, "", .None);
						_scanQueue.Add(newEntry);
						Path.Combine(newEntry.SubPath, currentEntry.SubPath, fileName);
					}
				}
				_nextFileMode = .None;
			}
			else if (File.Exists(sourcePath))
			{
				if (File.Exists(targetPath))
				{
					switch (CurrentFileMode)
					{
					case .KeepBoth, .OverwriteFile, .Skip:
					default:
						return .Err(.TargetFileExists(new String(fileName)));
					}
				}

				if (!CurrentFileMode.HasFlag(.Skip))
				{
					_pathsToCopy.Add(currentEntry);
					currentEntry.OverwriteMode = CurrentFileMode;
				}
				_nextFileMode = .None;
			}
		}

		_totalEntriesToCopy = _pathsToCopy.Count;

		return .Ok;
	}

	private CopyError _currentError = .None ~ _.Dispose();

	public override RunResult Run()
	{
		_currentError.Dispose();
		_currentError = .None;
		if (CollectFilesToCopy() case .Err(out _currentError))
		{
			return .Pause;
		}
		
		while (!_pathsToCopy.IsEmpty && Running)
		{
			//Thread.Sleep(1000);
			CopyInfo currentPath = _pathsToCopy.PopFront();

			defer
			{
				delete currentPath;
			}

			CopyPath(currentPath);
		}

		return .Finished;
	}

	private Result<void> CopyPath(CopyInfo copyInfo)
	{
		if (Directory.Exists(copyInfo.SourcePath))
		{
			//bool forceOverwrite = false;
			if (Directory.Exists(copyInfo.TargetPath))
			{
				switch (CurrentFileMode)
				{
				case .KeepBoth:
					String fileName = scope .();
					Path.GetFileName(copyInfo.SourcePath, fileName);

					Path.FindFreePath(_targetDirectoryPath, fileName, "", copyInfo.TargetPath..Clear());
				case .CombineDirectories:
					return .Ok;
				default:
					return .Err;//(.TargetDirectoryExists);
				}
			}

			Directory.CreateDirectory(copyInfo.TargetPath);
		}
		else if (File.Exists(copyInfo.SourcePath))
		{
			bool forceOverwrite = false;
			if (File.Exists(copyInfo.TargetPath))
			{
				switch (copyInfo.OverwriteMode)
				{
				case .KeepBoth:
					String fileExtension = scope .();
					Path.GetExtension(copyInfo.TargetPath, fileExtension);

					String fileName = scope .();
					Path.GetFileName(copyInfo.SourcePath, fileName);

					Path.FindFreePath(_targetDirectoryPath, fileName.Substring(0..<^fileExtension.Length), fileExtension, copyInfo.TargetPath..Clear());
				case .OverwriteFile:
					forceOverwrite = true;
				default:
					return .Err;//(.TargetFileExists);
				}
			}

			File.Copy(copyInfo.SourcePath, copyInfo.TargetPath, forceOverwrite);
		}
		else
		{
			// TODO error
			return .Err;
		}

		return .Ok;
	}

	public override void OnRenderPopup()
	{
		if (ImGui.Begin("Copying files..."))
		{
			if (ScanningFiles)
			{
				ImGui.ProgressBar(-1.0f * (float)ImGui.GetTime(), .(-1, 0), scope $"Found {_pathsToCopy.Count} files...");
			}
			else
			{
				int copiedFiles = _totalEntriesToCopy - _pathsToCopy.Count;

				ImGui.ProgressBar(copiedFiles / _totalEntriesToCopy, .(-1, 0), scope $"Copied {copiedFiles} / {_totalEntriesToCopy} files.");
			}

			switch (_currentError)
			{
			case .None:
				// Do nothing
			case .TargetDirectoryIsNotDirectory:
				// This shouldn't be possible
				Debug.Break();
			case .SourceDoesntExist(let SourcePath):
				// This isn't good!
			case .TargetFileExists(let fileName):
				ImGui.PushStyleColor(.Text, 0xFF0000FF);
				ImGui.TextUnformatted(scope $"A file with the name \"{fileName}\" already exists.");
				ImGui.PopStyleColor();

				if (ImGui.Button("Overwrite"))
				{
					_nextFileMode = .OverwriteFile;
					Continue();
				}
				ImGui.AttachTooltip("Overwrites the existing file. Will ask again if another conflict occurs.");

				if (ImGui.Button("Overwrite All"))
				{
					_allFilesMode = .OverwriteFile;
					Continue();
				}
				ImGui.AttachTooltip("Overwrites all existing files.");

				if (ImGui.Button("Keep both"))
				{
					_nextFileMode = .KeepBoth;
					Continue();
				}
				ImGui.AttachTooltip("Keeps both the existing file as well as the new one, differentiates by adding a number to the name. Will ask again if another conflict occurs.");

				if (ImGui.Button("Keep all"))
				{
					_allFilesMode = .KeepBoth;
					Continue();
				}
				ImGui.AttachTooltip("Keeps both the existing files as well as the new ones, differentiates by adding a number to the name.");
				
				if (ImGui.Button("Cancel"))
				{
					Abort();
				}
			case .TargetDirectoryExists(let directoryName):
				ImGui.PushStyleColor(.Text, 0xFF0000FF);
				ImGui.TextUnformatted(scope $"A file with the name \"{directoryName}\" already exists.");
				ImGui.PopStyleColor();

				if (ImGui.Button("Combine"))
				{
					_nextFileMode = .CombineDirectories;
					Continue();
				}
				ImGui.AttachTooltip("Merges the copied directory into the target directory. Will ask again if another conflict occurs.");

				if (ImGui.Button("Combine All"))
				{
					_allFilesMode = .CombineDirectories;
					Continue();
				}
				ImGui.AttachTooltip("Merges all copied directories into the target directories.");

				if (ImGui.Button("Keep both"))
				{
					_nextFileMode = .KeepBoth;
					Continue();
				}
				ImGui.AttachTooltip("Renames the copied directory, so that they no longer conflict. Will ask again if another conflict occurs.");

				if (ImGui.Button("Keep all"))
				{
					_allFilesMode = .KeepBoth;
					Continue();
				}
				ImGui.AttachTooltip("Renames the copied directory, so that they no longer conflict.");
				
				if (ImGui.Button("Cancel"))
				{
					Abort();
				}
			}
			
			ImGui.End();
		}
	}
}
