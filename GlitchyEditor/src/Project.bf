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
	public static Result<Project> CreateNew(StringView projectDirectory, StringView projectName)
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

			return .Err;
		}
	
		return project;
	}

	/// Creates a new project with the given name in the specified directory basend on the provided template.
	public static Result<Project> CreateNewFromTemplate(StringView projectDirectory, StringView projectName, StringView templatePath)
	{
		Project newProject = Try!(Project.CreateNew(projectDirectory, projectName));

		if (Project.InitializeTemplate(newProject, templatePath) case .Err)
		{
			delete newProject;
			return .Err;
		}

		return newProject;
	}

	/// Initializes a project with the provided template.
	public static Result<void> InitializeTemplate(Project project, StringView templatePath)
	{
		Try!(CopyTemplate(project, templatePath));
		
		Try!(RenameAndFixupFiles(project.WorkspacePath, project));

		return .Ok;
	}

	/// Copies the template files into the given project.
	private static Result<void> CopyTemplate(Project project, StringView templatePath)
	{
		if (Directory.Copy(templatePath, project.WorkspacePath) case .Err)
		{
			Log.EngineLogger.Error($"CopyTemplate: Failed to copy template {templatePath} to {project.WorkspacePath}.");
			return .Err;
		}

		return .Ok;
	}

	const String ProjectNamePlaceholder = "[ProjectName]";
	const String CoreLibPathPlaceholder = "[CoreLibPath]";
	
	/// Moves files so that [ProjectName] in their paths will be replaced by the actual project name
	private static Result<void> RenameAndFixupFiles(StringView directoryPath, Project project)
	{
		String fullPath = scope .(256);
		String modifiedFileName = scope String(256);

		for (FileFindEntry entry in Directory.Enumerate(scope $"{directoryPath}/*", .Files | .Directories))
		{
			entry.GetFilePath(fullPath..Clear());
			
			if (fullPath.Contains(ProjectNamePlaceholder))
			{
				modifiedFileName.Set(fullPath);
				modifiedFileName.Replace(ProjectNamePlaceholder, project.Name);

				if (entry.IsDirectory)
					Try!(Directory.Move(fullPath, modifiedFileName));
				else
					Try!(File.Move(fullPath, modifiedFileName));

				Swap!(fullPath, modifiedFileName);
			}

			if (entry.IsDirectory)
			{
				Try!(RenameAndFixupFiles(fullPath, project));
			}
			else
			{
				Try!(FixupFile(fullPath, project));
			}
		}

		return .Ok;
	}

	// Fixups a file by replacing placeholders for e.g. the project name.
	private static Result<void> FixupFile(StringView filePath, Project project)
	{
		String fileContent = scope String();
		if (File.ReadAllText(filePath, fileContent, true) case .Err)
		{
			Log.EngineLogger.Error($"FixupFile: Failed to read file {filePath}.");
			return .Err;
		}

		if (!fileContent.Contains(ProjectNamePlaceholder) && !fileContent.Contains(CoreLibPathPlaceholder))
			return .Ok;

		fileContent.Replace(ProjectNamePlaceholder, project.Name);

		// TODO: This is pretty bad, we don't really want to hard code the script core path like that!
		String scriptCorePath = scope .();
		Directory.GetCurrentDirectory(scriptCorePath);
		scriptCorePath.Append("/Resources/Scripts/ScriptCore.dll");
		fileContent.Replace(CoreLibPathPlaceholder, scriptCorePath);

		if (File.WriteAllText(filePath, fileContent, false) case .Err)
		{
			Log.EngineLogger.Error($"FixupFile: Failed to write file {filePath}.");
			return .Err;
		}

		return .Ok;
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