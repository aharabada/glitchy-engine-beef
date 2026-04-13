namespace BuildTool;

struct BuildInfo
{
    public WorkingDirectoryHistory WorkingDirectory;
    public bool ForceRebuild;
    public bool BuildDebug;
    public bool BuildRelease;

    public BuildInfo(WorkingDirectoryHistory workingDirectory, bool forceRebuild, bool buildDebug, bool buildRelease)
    {
        WorkingDirectory = workingDirectory;
        ForceRebuild = forceRebuild;
        BuildDebug = buildDebug;
        BuildRelease = buildRelease;
    }
}
