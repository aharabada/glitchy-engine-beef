namespace BuildTool;

public enum WatchMode
{
    /// <summary>
    /// Check if the files/directories have changed by comparing their metadata (e.g. last modified time).
    /// </summary>
    Metadata,
    /// <summary>
    /// For files only, check if the content of the file has changed by comparing a hash of the file contents.
    /// </summary>
    Content
}

internal record WatchedSource(string Path, WatchMode Mode)
{
    /// <summary>
    /// Path to a file or directory to be checked for changes.
    /// </summary>
    public string Path { get; init; } = Path;

    /// <summary>
    /// Gets or sets whether to check for changes in the file's metadata (e.g. last modified time) or content (e.g. hash of the file contents).
    /// </summary>
    public WatchMode Mode { get; init; } = Mode;

    /// <summary>
    /// Only if Path points to a directory, a list of subdirectories to exclude from change checking.
    /// </summary>
    public List<string> ExcludedDirectories { get; init; } = new();
    /// <summary>
    /// Only if Path points to a directory, whether to check for changes in subdirectories as well.
    /// </summary>
    public bool Recursive { get; init; } = true;
}
