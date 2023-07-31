using System;
using System.IO;
using Bon;
using GlitchyEngine;

namespace GlitchyEditor;

[BonTarget]
class Project
{
	[BonInclude]
	private String _projectName ~ delete _;

	[BonIgnore]
	private String _workspacePath ~ delete _;
	
	[BonIgnore]
	private String _assetsFolder ~ delete _;

	[BonIgnore]
	private String _scriptFolder ~ delete _;
	
	[BonIgnore]
	private ProjectUserSettings _userSettings ~ delete _;

	public StringView Name => _projectName;
	public StringView WorkspacePath => _workspacePath;

	public StringView AssetsFolder => _assetsFolder;

	public ProjectUserSettings UserSettings => _userSettings;

	[AllowAppend]
	private this(StringView workspacePath)
	{
		_workspacePath = new String(workspacePath);

		_assetsFolder = new String();
		PathInProject(_assetsFolder, "Assets");

		InitUserSettings();
	}
	
	/// Writes the the absolute path of the give project-file into target.
	/// @param target The string that will contain the full path.
	/// @param relativePath The path of the file relative to the workspace folder.
	public void PathInProject(String target, StringView relativePath)
	{
		Path.Combine(target, WorkspacePath, relativePath);
	}

	/// Creates a new scoped string that contains the absolute path of the give project-file
	/// @param relativePath The path of the file relative to the workspace folder.
	public mixin GetScopedPath(StringView relativePath)
	{
		String target = scope:mixin String();

		PathInProject(target, relativePath);

		target
	}

	/// Loads or creates the user specific settings for this project.
	private void InitUserSettings()
	{
		_userSettings = new ProjectUserSettings();

		String userSettingsFile = scope .();
		PathInProject(userSettingsFile, ProjectUserSettings.FileName);

		// It's not a problem if we couldn't find or deserialize the settings. We will simply restore the defaults.
		if (Bon.DeserializeFromFile(ref _userSettings, userSettingsFile) case .Err)
		{
			// Log anyway, just in case...
			Log.EngineLogger.Info($"Failed to deserialize project user settings file \"{userSettingsFile}\".");
			_userSettings.RestoreDefaults();
		}
	}

	public void SaveUserSettings()
	{
		if (_userSettings == null || !_userSettings.SettignsDirty)
			return;

		String userSettingsFile = scope .();
		PathInProject(userSettingsFile, ProjectUserSettings.FileName);

		// It's not a big problem, if we fail to serialize this file.
		if (Bon.SerializeIntoFile(_userSettings, userSettingsFile) case .Err)
		{
			// Log anyway, just in case...
			Log.EngineLogger.Error($"Failed to deserialize project user settings file \"{userSettingsFile}\".");
		}
	}

	/// Creates a new project with the given directory and name.
	public static Project CreateNew(StringView projectDirectory, StringView projectName)
	{
		Project project = new Project(projectDirectory);
		project._projectName = new String(projectName);

		String settingsFile = scope .();
		project.PathInProject(settingsFile, "project.gep");

		/// This is not really fatal, however the project might end up unusable
		if (Bon.SerializeIntoFile(project, settingsFile) case .Err)
		{
			Log.EngineLogger.Warning($"Failed to save project file \"{settingsFile}\".");
			delete project;

			return null;
		}
	
		return project;
	}

	public static Result<Project> Load(StringView projectDirectory)
	{
		Project project = new Project(projectDirectory);

		String settingsFile = scope .();
		project.PathInProject(settingsFile, "project.gep");

		if (File.Exists(settingsFile))
		{
			Result<void> result = Bon.DeserializeFromFile(ref project, settingsFile);

			if (result case .Err)
				Log.EngineLogger.Warning($"Failed to deserialize project file \"{settingsFile}\".");
		}
		else
		{
			Log.EngineLogger.Warning($"Project file \"{settingsFile}\" doesn't exist.");

			if (project.Name.IsWhiteSpace)
			{
				project._projectName ??= new String();

				Path.GetFileName(project.WorkspacePath, project._projectName);
				
				/// This is not really fatal, however the project might end up unusable
				if (Bon.SerializeIntoFile(project, settingsFile) case .Err)
				{
					Log.EngineLogger.Warning($"Failed to save project file \"{settingsFile}\".");
					delete project;

					return null;
				}
			}
		}

		return project;
	}
}