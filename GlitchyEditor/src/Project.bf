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

	public static Project CreateNew(StringView projectDirectory, StringView projectName)
	{
		Project project = new Project(projectDirectory);
		project._projectName = new String(projectName);

		String settingsFile = scope .();
		project.PathInProject(settingsFile, "project.gep");

		Result<void> result = Bon.SerializeIntoFile(project, settingsFile);

		if (result case .Err)
			Log.EngineLogger.Warning($"Failed to save project file \"{settingsFile}\".");
	
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
				if (project._projectName == null)
					project._projectName = new String();

				Path.GetFileName(project.WorkspacePath, project._projectName);
				
				Result<void> result = Bon.SerializeIntoFile(project, settingsFile);

				if (result case .Err)
					Log.EngineLogger.Warning($"Failed to save project file \"{settingsFile}\".");
			}
		}


		return project;
	}
}