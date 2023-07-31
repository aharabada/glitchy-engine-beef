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

	public StringView Name => _projectName;
	public StringView WorkspacePath => _workspacePath;

	public StringView AssetsFolder => _assetsFolder;

	[AllowAppend]
	private this(StringView workspacePath)
	{
		_workspacePath = new String(workspacePath);

		_assetsFolder = new String();
		PathInProject(_assetsFolder, "Assets");
	}

	public void PathInProject(String target, StringView relativePath)
	{
		Path.Combine(target, WorkspacePath, relativePath);
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